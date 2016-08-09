if [ "$1" == "-d" ]; then
   shift
   set -x
   trap read debug
fi

action=$1

mkdir -p src work

url=http://sourceforge.net/projects/trousers/files/tpm-tools/1.3.8/tpm-tools-1.3.8.tar.gz
file=${url##*/}
dir=${file%.tar.gz}
pkg=$dir-7
spec=dist/tpm-tools.spec
specf=${spec##*/}

if [ "$action" == "1" -o -z "$action" ]; then
   [ -f src/$file ] || wget $url -P src
   [ -d work/$dir ] && rm -rf work/$dir/
   (
   cd work
   tar zxf ../src/$file
   cd $dir
   id tss &> /dev/null || sudo useradd -r tss
   sudo yum install -y opencryptoki-devel automake autoconf libtool openssl openssl-devel gtk+ trousers trousers-devel
   sudo ln -s /usr/lib64/libtspi.so.1 /usr/lib64/libtspi.so
   ./configure
   )
fi

if [ "$action" == "2" -o "$action" == "3" -o -z "$action" ]; then
   cp -f src/$file ~/rpmbuild/SOURCES/
   cp -f work/$dir/$spec ~/rpmbuild/SPECS/
   sed -i 's/libtpm_unseal.so.0/libtpm_unseal.so.?/' ~/rpmbuild/SPECS/$specf
   sed -i 's/opencryptoki-devel/opencryptoki/g' ~/rpmbuild/SPECS/$specf
   sed -ri 's/(define\s+release\s+)1/\17/g' ~/rpmbuild/SPECS/$specf
   rpmbuild -bs ~/rpmbuild/SPECS/$specf
   if [ "$action" == "2" -o -z "$action" ]; then
      mock -r rhel --clean
   fi
   home=$( echo ~makerpm )
   mock -r rhel --yum-cmd install opencryptoki-devel trousers trousers-devel
   mock -r rhel --resultdir=$home/rpmbuild/RPMS/ ~/rpmbuild/SRPMS/$pkg.src.rpm --no-clean --no-cleanup-after
fi
