#!/bin/sh
##
## USAGE:
##   ./onie-mk-demo2.sh {img name} {path to pack data} {path to sharch_body.sh}

clean_up()
{
    exit $1
}

echo -n "Building self-extracting install image ."

output_file=$1
tmp_dir=$2
installer_dir=$3

shift 3

sharch="$tmp_dir/sharch.tar"
tar -C $tmp_dir -cf $sharch installer || {
    echo "Error: Problems creating $sharch archive"
    clean_up 1
}
echo -n "."

[ -f "$sharch" ] || {
    echo "Error: $sharch not found"
    clean_up 1
}
sha1=$(cat $sharch | sha1sum | awk '{print $1}')
echo -n "."
cp $installer_dir/sharch_body.sh $output_file || {
    echo "Error: Problems copying sharch_body.sh"
    clean_up 1
}

# Replace variables in the sharch template
sed -i -e "s/%%IMAGE_SHA1%%/$sha1/" $output_file
echo -n "."
cat $sharch >> $output_file
rm -rf $sharch 
echo " Done."

echo "Success:  Demo install image is ready in ${output_file}:"
ls -l ${output_file}

clean_up 0
