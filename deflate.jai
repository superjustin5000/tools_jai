




//NOTE(justin):structured in blocks in case of files like png that store deflate packets in chunks.
//BUT can just store the entire data object in single block.

Deflate_Block_Data :: struct {
    data: *u8;
    size_bytes: u32;
    byte_reading: u8;
    byte_reading_bits: u8 = 8;
    bytes_read: u32 = 0;
	first: *Deflate_Block_Data;
	next: *Deflate_Block_Data;
};



#import "Basic";
#import "common";



deflate_length_codes: [29][2]u16 = .[
                                     .[0,3],.[0,4],.[0,5],.[0,6],.[0,7],.[0,8],.[0,9],.[0,10],
                                     .[1,11],.[1,13],.[1,15],.[1,17],
                                     .[2,19],.[2,23],.[2,27],.[2,31],
                                     .[3,35],.[3,43],.[3,51],.[3,59],
                                     .[4,67],.[4,83],.[4,99],.[4,115],
                                     .[5,131],.[5,163],.[5,195],.[5,227],
                                     .[0, 258]
                                     ];

deflate_distance_codes: [30][2]u16 = .[
                                       .[0, 1], .[0, 2], .[0, 3], .[0, 4], 
                                       .[1, 5], .[1, 7], 
                                       .[2, 9], .[2, 13], 
                                       .[3, 17], .[3, 25],
                                       .[4, 33], .[4, 49],
                                       .[5, 65], .[5, 97], 
                                       .[6, 129],.[6, 193], 
                                       .[7, 257],.[7, 385], 
                                       .[8, 513], .[8, 769],
                                       .[9, 1025], .[9, 1537], 
                                       .[10, 2049], .[10, 3073], 
                                       .[11, 4097], .[11, 6145], 
                                       .[12, 8193], .[12, 12289], 
                                       .[13, 16385], .[13, 24577]
                                       ];





read_data_bits :: (chunkData: **Deflate_Block_Data, bits: u8) -> u32 {
    assert(bits <= 16 && bits > 0);
    chunk := <<chunkData;
    
    result: u32 = 0;
    for bit_index: 0..bits-1 {
        if chunk.byte_reading_bits == 0 {
            chunk.bytes_read +=1 ;
            if chunk.bytes_read >= chunk.size_bytes {
                assert(chunk.next != null);
                assert(chunk.next.data != null);
                <<chunkData = chunk.next;
                chunk = <<chunkData;
                chunk.bytes_read = 0;
            }
            else {
                chunk.data = chunk.data + 1;
            }
            chunk.byte_reading = <<chunk.data;
            chunk.byte_reading_bits = 8;
        }
        next_bit: u32 = cast(u32)chunk.byte_reading & 1;
        bit_in_position: u32 = next_bit << bit_index;
        result |= bit_in_position;
        chunk.byte_reading  = chunk.byte_reading >> 1;
        chunk.byte_reading_bits -= 1;
    }
    return result;
}



peek_bits_in_reverse :: (chunk: *Deflate_Block_Data, bits: u32) -> u32 {
    data: *u8             = chunk.data;
    size_bytes: u32       = chunk.size_bytes;
    byte_reading: u8      = chunk.byte_reading;
    byte_reading_bits: u8 = chunk.byte_reading_bits;
    bytes_read: u32       = chunk.bytes_read;
    
    result: u32 = 0;
    for bit_index: 0 .. bits-1 {
        if byte_reading_bits == 0 {
            bytes_read += 1;
            if bytes_read >= size_bytes {
                
                assert(chunk.next != null);
                assert(chunk.next.data != null);
                
                data = chunk.next.data;
                bytes_read = 0;
                size_bytes = chunk.next.size_bytes;
            }
            else {
                data += 1;
            }
            byte_reading = <<data;
            byte_reading_bits = 8;
        }
        next_bit: u32 = cast(u32)byte_reading & 1;
        bit_in_position: u32 = next_bit << ((bits - bit_index) - 1);
        result |= bit_in_position;
        byte_reading = byte_reading >> 1;
        byte_reading_bits -= 1;
    }
    return result;
}






CODE_LEN_CODE_ALPHA_SIZE :: 19;
CODE_LITLEN_ALPHA_SIZE :: 288;
CODE_DIST_ALPHA_SIZE :: 32;
CODE_ALPHA_SIZE :: 320;
LIT_LEN_STOP_CODE :: 256;


build_huffman_codes_from_code_length_counts :: (code_lengths: *u8, size: u32, result: *u32) {
    
    longest_code_length: u8 = 0;
    for 0 .. size-1 {
        if longest_code_length < code_lengths[it] {
            longest_code_length = code_lengths[it];
        }
    }
    num_code_lengths: u32 = longest_code_length + 1;
    
    //each index of code_length_counts represents a length, i=0 is num codes of length 0.
    code_length_counts: [CODE_ALPHA_SIZE] u8;
    
    for 0 .. size-1 {
        length_index: u32 = code_lengths[it];
        current_count_of_length: = code_length_counts[length_index];
        code_length_counts[length_index] = current_count_of_length + 1;
    }
    code_length_counts[0] = 0;
    
    //next codes initialized with the first code of each length, length being the index.
    next_codes: [CODE_ALPHA_SIZE] u32;
    code: u32 = 0;
    for bit_length: 1 .. longest_code_length {
        count_of_prev_code_length: u8 = code_length_counts[bit_length - 1];
        code = (code + count_of_prev_code_length) << 1;
        next_codes[bit_length] = code;
    }
    
    //we have to assign code to every element in alphabet even if we have to assign 0.
    //uint32* assignedCodes = (uint32*)malloc(size * sizeof(uint32));
    for 0 .. size-1 {
        code_length: u32 = code_lengths[it];
        if code_length != 0 {
            next_code_of_this_length: u32 = next_codes[code_length];
            result[it] = next_code_of_this_length;
            //increment the prev code of the length so the next assignment to the same length has 1 higher value.
            next_codes[code_length] = next_code_of_this_length + 1;
        }
    }
}


decode_huffman_symbol :: (data: **Deflate_Block_Data, codes: *u32, code_lengths: *u8, num_symbols: u32, decoded_symbol: *u32) -> bool {
    found := false;
    for symbol_index: 0 .. num_symbols-1 {
        
        bits_to_read: u8 = code_lengths[symbol_index];
        
        if bits_to_read == 0 continue;
        
        code: u32 = peek_bits_in_reverse(<<data, bits_to_read);
        if codes[symbol_index] == code {
            <<decoded_symbol = symbol_index;
            found = true;
            read_data_bits(data, bits_to_read);
            break;
        }
    }
    return found;
}







#scope_export





//NOTE(justin) uncompressd size is precalculated depending on the desired output data format.
deflate_decompress :: (current_data: *Deflate_Block_Data, uncompressed: *u8) -> u32 {
    
    //NOTE(justin): this is more specific to zlib and not deflate in general.
    zlib_method_flags: u8 = cast(u8)read_data_bits(*current_data, 8);
    zlib_additional_flags: u8 = cast(u8)read_data_bits(*current_data, 8);
    
    CM: u8 = zlib_method_flags & 0xF;
    CINFO: u8 = zlib_method_flags >> 4;
    FCHECK: u8 = zlib_additional_flags & 0b11111;
    FDICT: u8 = zlib_additional_flags & 0b00100000;
    FLEVEL: u8 = zlib_additional_flags >> 6;
    
    
    uncompressed_size: u32 = 0;
    block_count: u32 = 1;
    while true {
        
        BFINAL: u32 = read_data_bits(*current_data, 1);
        BTYPE: u32 = read_data_bits(*current_data, 2);
        
        
        if BTYPE == 0 {
            /*
              skip any remaining bits in current partially
               processed byte
              read LEN and NLEN (see next section)
              copy LEN bytes of data to output
              */
            if (current_data.byte_reading_bits) {
                read_data_bits(*current_data, current_data.byte_reading_bits);
            }
            
            LEN  := read_data_bits(*current_data, 16);
            NLEN := read_data_bits(*current_data, 16);
            
            for 0 .. LEN-1 {
                <<(uncompressed + uncompressed_size) = cast(u8)read_data_bits(*current_data, 8);
                uncompressed_size += 1;
            }
        }
        else if BTYPE == 1 || BTYPE == 2 {
            HLIT: u32 = 257;
            HDIST: u32 = 1;
            HCLEN: u32 = 4;
            
            lit_len_huff_tree: [CODE_LITLEN_ALPHA_SIZE] u32;
            dist_huff_tree: [CODE_DIST_ALPHA_SIZE] u32;
            decoded_code_lengths: [CODE_ALPHA_SIZE] u8;
            
            
            if BTYPE == 2 {
                
                HLIT += read_data_bits(*current_data, 5);
                HDIST += read_data_bits(*current_data, 5);
                HCLEN += read_data_bits(*current_data, 4);
                
                
                code_length_index_order: [19] u8 = .[ 16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15 ];
                
                code_lengths: [CODE_LEN_CODE_ALPHA_SIZE] u8; //size is element count of array above.
                
                for code_length_index: 0 .. HCLEN-1 {
                    code_length: u32 = read_data_bits(*current_data, 3);
                    real_index: u8 = code_length_index_order[code_length_index];
                    code_lengths[real_index] = cast(u8)code_length;
                }
                
                
                huff_codes: [CODE_LEN_CODE_ALPHA_SIZE] u32;
                build_huffman_codes_from_code_length_counts(code_lengths.data, CODE_LEN_CODE_ALPHA_SIZE, huff_codes.data);
                
                
                code_index: u32 = 0;
                while code_index < (HLIT + HDIST) {
                    
                    //alphabet symbol is one of 0-18 from above.
                    code_length_alphabet_symbol: u32 = 0;
                    success:= decode_huffman_symbol(*current_data, huff_codes.data, code_lengths.data, CODE_LEN_CODE_ALPHA_SIZE, *code_length_alphabet_symbol);
                    if !success {
                        invalid_code_path("DECODE HUFFMAN FAILED FOR CODE INDEX: %", code_index);
                    }
                    
                    if code_length_alphabet_symbol < 16 {
                        decoded_code_lengths[code_index] = cast(u8)code_length_alphabet_symbol;
                        code_index += 1;
                    }
                    else {
                        
                        repeat_count: u32 = 0;
                        codeLengthToRepeat: u8 = 0;
                        
                        if code_length_alphabet_symbol == 16 {
                            repeat_count = read_data_bits(*current_data, 2) + 3;
                            codeLengthToRepeat = decoded_code_lengths[code_index - 1];
                        }
                        else if code_length_alphabet_symbol == 17 {
                            repeat_count = read_data_bits(*current_data, 3) + 3;
                        }
                        else if code_length_alphabet_symbol == 18 {
                            repeat_count = read_data_bits(*current_data, 7) + 11;
                        }
                        
                        for repeat_index: 0 .. repeat_count-1 {
                            decoded_code_lengths[code_index] = codeLengthToRepeat;
                            code_index += 1;
                        }
                    }
                }
                
                
            }
            
            else if (BTYPE == 1) {
                
                HLIT = CODE_LITLEN_ALPHA_SIZE;
                
                for length_index: 0 .. HLIT-1 {
                    if length_index >= 280 {
                        decoded_code_lengths[length_index] = 8;
                    }
                    else if length_index >= 256 {
                        decoded_code_lengths[length_index] = 7;
                    }
                    else if length_index >= 144 {
                        decoded_code_lengths[length_index] = 9;
                    }
                    else {
                        decoded_code_lengths[length_index] = 8;
                    }
                }
                
                HDIST = CODE_DIST_ALPHA_SIZE;
                
                for length_index: 0 .. HDIST-1 {
                    decoded_code_lengths[HLIT + length_index] = 5;
                }
            }
            
            
            build_huffman_codes_from_code_length_counts(decoded_code_lengths.data, HLIT, lit_len_huff_tree.data);
            build_huffman_codes_from_code_length_counts(decoded_code_lengths.data + HLIT, HDIST, dist_huff_tree.data);
            
            success_count:u32 = 0;
            
            while true {
                
                length_code: u32 = 0;
                success:= decode_huffman_symbol(*current_data, lit_len_huff_tree.data, decoded_code_lengths.data, HLIT, *length_code);
                if !success {
                    print("failed after % successes\n", success_count);
                    invalid_code_path("DECODE HUFFMAN FAILED FOR LENGTH CODE");
                }
                success_count += 1;
                
                assert(length_code < CODE_LITLEN_ALPHA_SIZE-2);
                
                if length_code == LIT_LEN_STOP_CODE {
                    break;
                }
                else if length_code < LIT_LEN_STOP_CODE {
                    <<(uncompressed + uncompressed_size) = cast(u8)length_code;
                    uncompressed_size += 1;
                }
                else if length_code > LIT_LEN_STOP_CODE {
                    length_index: u32 = length_code - (LIT_LEN_STOP_CODE + 1);
                    length_extra: u16 = deflate_length_codes[length_index][0];
                    length: u16 = deflate_length_codes[length_index][1];
                    if (length_extra > 0) {
                        assert(length_extra <= 5);
                        extra_bits_value: u32 = read_data_bits(*current_data, cast(u8)length_extra);
                        length += cast(u16)extra_bits_value;
                    }
                    
                    dist_code: u32 = 0;
                    success: = decode_huffman_symbol(*current_data, dist_huff_tree.data, decoded_code_lengths.data + HLIT, HDIST, *dist_code);
                    if !success {
                        invalid_code_path("DECODE HUFFMAN FAILED FOR LENGTH CODE");
                    }
                    
                    assert(dist_code < CODE_DIST_ALPHA_SIZE-2);
                    
                    dist_extra: u16 = deflate_distance_codes[dist_code][0];
                    dist: u32 = deflate_distance_codes[dist_code][1];
                    
                    if (dist_extra > 0) {
                        assert(dist_extra <= 13);
                        extra_dist_value: u32 = read_data_bits(*current_data, cast(u8)dist_extra);
                        dist += extra_dist_value;
                    }
                    
                    assert(dist <= uncompressed_size);
                    
                    start_copy: *u8 = (uncompressed + uncompressed_size) - dist;
                    for copy_index: 0 .. length-1 {
                        <<(uncompressed + uncompressed_size) = <<(start_copy + copy_index);
                        uncompressed_size += 1;
                    }
                }
            }
            
        }
        else {
            invalid_code_path("unsupported btype: %", BTYPE);
        }
        
        if (BFINAL == 1) {
            break;
        }
        block_count += 1;
    }
    return uncompressed_size;
}




deflate_decompress :: (compressed: *u8, compressed_len: u32, uncompressed: *u8) -> u32 {
    deflate_block_data: Deflate_Block_Data = .{};
    deflate_block_data.data = compressed;
    deflate_block_data.size_bytes = compressed_len;
    deflate_block_data.byte_reading = <<compressed;
    deflate_block_data.first = *deflate_block_data;
    result: u32 = deflate_decompress(*deflate_block_data, uncompressed);
    return result;
}