import mmap
import os
import time

fd = os.open("/dev/gpiomem", os.O_RDWR | os.O_SYNC)
mem = mmap.mmap(fd, 4096, mmap.MAP_SHARED, mmap.PROT_READ)
print("Sampling GPIO 18 levels (Ctrl+C to stop)...")
while True:
    mem.seek(0x34)  # GPLEV0
    high = sum((int.from_bytes(mem.read(4), "little") >> 18) & 1 for _ in range(500))
    duty = (high / 500) * 100
    bars = "█" * int(duty // 4)
    print(f"GPIO18 measured duty: {duty:5.1f}%  |  {bars}")
    time.sleep(0.1)
