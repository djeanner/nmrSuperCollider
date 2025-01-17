usage:

```
python3 convert.py 300.0 5.0
```

Where the first parameter is the larmor frequency and the second the minimal intensity to be retained (in %). 
Output relative to 1.0.
Negative frequencies are removed

Run `src/readFrequenciesAmplitudesFromFile.scd` in collider (start a sever)...

Copy/past the following in a terminal to switch file every 3 seconds. (I collider is open, it will change the sound it makes...)

```
echo "Start with list1_orig ....."
cp ../list1_orig.txt ../list1.txt
sleep 10
echo "djhap_phenanthrene"
cp djhap_phenanthrene.10.1.1r.list ../list1.txt
sleep 5
cp ODCB.1.1.1r-1.list ../list1.txt
echo "ODCB"
sleep 5
cp TST100053.10.fid-1.list ../list1.txt
echo "TST100053"
sleep 5
cp djcyclokeel2.8.fid.list ../list1.txt
echo "djcyclokeel2"
sleep 5
cp TST100068.10.fid-1.list ../list1.txt
echo "TST100068"
sleep 5
cp ../list1_orig.txt ../list1.txt
echo "back to list1_orig ....."

```

