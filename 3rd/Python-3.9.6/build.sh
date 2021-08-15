#prepare
echo "prepare stage"
arm_install=`pwd`/_install
arm_build=`pwd`/arm_build
mkdir -p $arm_build
mkdir -p $arm_install
cd `pwd`
#arm comfigure
echo "arm confiure stage"
cd $arm_build
echo ac_cv_file__dev_ptmx=yes > config.site
echo ac_cv_file__dev_ptc=yes >> config.site
export CONFIG_SITE=config.site
../configure --host=arm-none-linux-gnueabi --build=i686-linux-gnu --target=arm-none-linux-gnueabi --disable-ipv6 --prefix=$arm_install --enable-shared --silent
 
#pc pgen
echo "pc pgen stage"
cd - 
./configure --silent
for args in $@
do
if [ $args = "all" ];then
make --silent && make install --silent
break
fi
done
make Parser/pgen --silent
cd -
cp ../Parser/pgen Parser
#change the pgen time,
# or else the cross compile will replace this pc version pgen. important!!
touch -t 12312359 Parser/pgen
 
#make
echo "make stage"
make python --silent && make -i install
 
#make it smaller
#arm-none-linux-gnueabi-strip -s $arm_install/bin/python3.3
exit 0
