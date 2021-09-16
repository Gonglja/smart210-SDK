#!/bin/bash
make clean && make distclean
make smart210_config
make -j4
