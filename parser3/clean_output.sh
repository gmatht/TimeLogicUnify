mkdir output_clean
cd output && for f in * 
do
	echo $f
	grep -v .................................................................................................................................................................................................................................................................................................................................................................................................................... < $f > ../output_clean/$f
done

D=`date +%F`
tar -zcf output_clean_$D.tar.gz output_clean
scp output_clean_$D.tar.gz $GMx:
exit

