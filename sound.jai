

Sound :: struct {
    size: u32;
    bytesPerSample: u16;
    samplesPerSecond: u16;
    channels: u16;
	data: *s16;
};

sound_valid :: inline (sound: Sound) -> bool {
    return sound.data != null;
}
