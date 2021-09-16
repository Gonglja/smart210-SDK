#!/bin/bash
DST=/dev/sdb
sudo dd iflag=sync oflag=sync if=spl/smart210-spl.bin of=$DST seek=1
sudo dd iflag=sync oflag=sync if=u-boot.bin of=$DST  seek=32
sync
echo "done."
