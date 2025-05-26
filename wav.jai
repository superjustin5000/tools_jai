



#scope_file

#import "Basic";
#import "common";

#import "file_io_common";
#import "sound";

// - PCM FORMAT LAYOUT    - http://soundfile.sapp.org/doc/WaveFormat/
// - OTHER LAYOUT INFO    - https://www.mmsp.ece.mcgill.ca/Documents/AudioFormats/WAVE/WAVE.html
// - FORMAT SPECIFIC INFO - https://www.opennet.ru/docs/formats/wavecomp.html
// - AL SOFT MSADPCM INFO - https://openal-soft.org/openal-extensions/SOFT_MSADPCM.txt
// - OTHER INFO           - http://soundfile.sapp.org/doc/WaveFormat/

Wave_Format :: enum u16 {
    PCM           :: 0x0001;
    MSADPCM       :: 0x0002;
    IEEE_Float    :: 0x0003;
    Alaw          :: 0x0006;
    Mulaw         :: 0x0007;
    Format_Ext    :: 0xFFFE;
};


Wave_Chunk_Header :: struct {
    id: u32 #align 4;
    size: u32 #align 4;
} #no_padding

// NOTE(justin): only the basic(PCM) format data.. extended formats have more data after this.
Wave_Format_Chunk :: struct {
    format: Wave_Format #align 2;
    channelCount: u16 #align 2;
    sampleRate: u32 #align 4;
    byteRate: u32 #align 4;
    blockAlign: u16 #align 2;
    bitsPerSample: u16 #align 2;
} #no_padding




/* MSADPCM Adaption table */
// https://freeswitch.org/stash/projects/SD/repos/openal/browse/OpenAL32/sample_cvt.c
adpcm_adaption_table: [16] s16 = .[230, 230, 230, 230, 307, 409, 512, 614,
                                   768, 614, 512, 409, 307, 230, 230, 230];



process_chunk :: (block: *Consumeable_Data_Block, header: *Wave_Chunk_Header, snd: *Sound) {
    consume_data_size(block, header.size);
}

process_chunks_until_data_chunk :: (block: *Consumeable_Data_Block, snd: *Sound) -> Wave_Chunk_Header {
    header:= consume_data(block, Wave_Chunk_Header);
    while (magic_number("data") != header.id) {
        process_chunk(block, header, snd);
        header = consume_data(block, Wave_Chunk_Header);
    }
    return header;
}

process_remaining_chunks :: (block: *Consumeable_Data_Block, snd: *Sound) {
    while(block.remaining_size) {
        header := consume_data(block, Wave_Chunk_Header);
        process_chunk(block, header, snd);
    }
}

wave_skip_junk_chunks :: (block: *Consumeable_Data_Block) {
    header: *Wave_Chunk_Header = cast(*Wave_Chunk_Header)block.data;
    while(header.id == magic_number("JUNK") || header.id == magic_number("junk")) {
        consume_data(block, Wave_Chunk_Header);
        consume_data_size(block, header.size);
        header = cast(*Wave_Chunk_Header)block.data;
    }
}



#scope_export




wav_load :: (wav_data: *u8, wav_data_size: u64) -> bool, Sound {
    
    worked := true;
    snd: Sound = .{};
    
    data_block := get_consumeable_data_block(wav_data, wav_data_size);
    
    riff_chunk := consume_data(*data_block, Wave_Chunk_Header);
    assert(magic_number("RIFF") == riff_chunk.id);
    
    wave_format_id := consume_data_value(*data_block, u32);
    assert(magic_number("WAVE") == wave_format_id);
    
    wave_skip_junk_chunks(*data_block);
    
    format_chunk_header := consume_data(*data_block, Wave_Chunk_Header);
    assert(magic_number("fmt ") == format_chunk_header.id);
    
    format_info := consume_data(*data_block, Wave_Format_Chunk);
    
    snd.channels = format_info.channelCount;
    snd.samplesPerSecond = cast(u16)format_info.sampleRate;
    
    if (format_info.format == .PCM) {
        
        data_chunk_header := process_chunks_until_data_chunk(*data_block, *snd);
        data: *s16 = cast(*s16)consume_data_size(*data_block, data_chunk_header.size);
        
        snd.bytesPerSample = format_info.bitsPerSample / 8;
        // NOTE(justin): currently can't handle anything other than 2 bytes per sample.
        if snd.bytesPerSample != 2 {
            worked = false;
        }
        else {
            snd.size = data_chunk_header.size;
            snd.data = cast(*s16)alloc(snd.size);
            
            sampleSize:= snd.bytesPerSample * snd.channels;
            samples: u32 = snd.size / sampleSize;
            
            for sample_index: 0..samples-1 {
                for channel_index: 0..snd.channels-1 {
                    index := (sample_index * snd.channels) + channel_index;
                    <<(snd.data + index) = <<(data + index);
                }
            }
        }
        
    } else {
        
        //NON PCM types have more info.. the amount is determined by cb size.
        
        cb_size: u16 = consume_data_value(*data_block, u16);
        assert(cb_size > 0);
        
        if (format_info.format == .MSADPCM) {
            
            // each sample in the block corresponds to 2 bytes of audio output PER channel
            samples_per_block := consume_data_value(*data_block, u16);
            
            // multiplied by two: each one is a set of two values.
            num_coef := consume_data_value(*data_block, u16) * 2;
            
            coef : *s16 = cast(*s16)consume_data_size(*data_block, num_coef * 2);
            
            fact_chunk_header := consume_data(*data_block, Wave_Chunk_Header);
            assert(magic_number("fact") == fact_chunk_header.id);
            samples_per_channel := consume_data_value(*data_block, u32);
            
            
            data_chunk_header := process_chunks_until_data_chunk(*data_block, *snd);
            data_size := data_chunk_header.size;
            
            chan_count := format_info.channelCount;
            
            assert(chan_count == 2, "Only stereo supported");
            // NOTE(justin): currently only supporting stereo if this format is present.
            // mono should require a change to how the nibbles are being processed.
            
            snd.bytesPerSample = 2; //should always be 16 bit.
            
            
            block_align := format_info.blockAlign;
            
            blocks := data_size / block_align;
            
            non_sound_header_bytes : u32 = chan_count * 3;
            sound_header_bytes : u32 = chan_count * 4;
            header_bytes := non_sound_header_bytes + sound_header_bytes;
            block_data_bytes := block_align - header_bytes;
            
            bytes_output_per_sample_input : u32 = snd.bytesPerSample * chan_count;
            
            block_output_size := (bytes_output_per_sample_input * block_data_bytes) + sound_header_bytes;
            
            snd.size = block_output_size * blocks;
            snd.data = cast(*s16)alloc(snd.size);
            data := snd.data;
            
            snd_data_index : u32 = 0;
            
            
            block_samples_to_decode : u16 = samples_per_block - 2; //first 2 are given in the header.
            
            
            block_padding_bits : u32 = ((block_align - (7 * chan_count)) * 8) - ((block_samples_to_decode * chan_count) * 4);
            assert(block_padding_bits == 0);
            // NOTE(justin): currently not handling padding bits.. if they exist, they should be 4 if anything
            // since 4 is all we're consuming per sample
            
            
            while (blocks) {
                
                max_channels : u8 : 2;
                
                b_predictors: [max_channels]u8;
                i_deltas: [max_channels]s16;
                i_samples1: [max_channels]s16;
                i_samples2: [max_channels]s16;
                
                
                for 0..chan_count-1 {
                    b_predictors[it] = consume_data_value(*data_block, u8);
                }
                for 0..chan_count-1 {
                    i_deltas[it] = consume_data_value(*data_block, s16);
                }
                for 0..chan_count-1 {
                    i_samples1[it] = consume_data_value(*data_block, s16);
                }
                for 0..chan_count-1 {
                    i_samples2[it] = consume_data_value(*data_block, s16);
                }
                
                for 0..chan_count-1 {
                    <<(data + snd_data_index) = i_samples1[it]; 
                    snd_data_index+=1;
                }
                for 0..chan_count-1 {
                    <<(data + snd_data_index) = i_samples2[it]; 
                    snd_data_index+=1;
                }
                
                
                
                for 0 .. block_samples_to_decode-1 {
                    
                    nibble_byte := consume_data_value(*data_block, u8);
                    
                    for chan_index: 0..chan_count-1 {
                        
                        nibble:s8 = 0;
                        if (chan_index == 0) {
                            nibble = cast(s8)((nibble_byte >> 4) & 0x0F);
                        } else {
                            nibble = cast(s8)((nibble_byte) & 0x0F);
                        }
                        
                        coef_index := b_predictors[chan_index];
                        if coef_index > 6 coef_index = 6;
                        coef_index *= 2; //because they are in sets of 2.
                        
                        coef1 := <<(coef + coef_index);
                        coef2 := <<(coef + coef_index + 1);
                        
                        samp1 := i_samples1[chan_index];
                        samp2 := i_samples2[chan_index];
                        
                        delta := i_deltas[chan_index];
                        
                        new_sample : s32 = ((samp1 * coef1) + (samp2 * coef2)) / 256;
                        new_sample += (ifx nibble >= 8 then nibble - 16 else nibble) * delta;
                        
                        if new_sample > 32767 new_sample = 32767;
                        else if new_sample < -32768 new_sample = -32768;
                        
                        <<(data + snd_data_index) = cast(s16)new_sample;
                        snd_data_index += 1;
                        
                        delta = (delta * adpcm_adaption_table[nibble]) / 256;
                        if delta < 16 delta = 16;
                        
                        i_deltas[chan_index]   = delta;
                        i_samples2[chan_index] = samp1;
                        i_samples1[chan_index] = cast(s16)new_sample;
                        
                    }
                    
                    
                    
                }
                
                
                blocks -= 1;
            }
            
            
        } else {
            invalid_code_path("Unsupported wave format %s", format_info.format);
        }
        
    }
    
    process_remaining_chunks(*data_block, *snd);
    
    return worked, snd;
}








