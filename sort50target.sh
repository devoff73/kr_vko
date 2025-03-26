#!/bin/bash
#

#Help Function

decrypt_filename(){

local filename="$1"

local interleaved="${filename:0:-2}"

local hex_part=""

for((i=0; i<${#interleaved}; i+=4)); do
hex_part+="${interleaved:$i+2:2}"
done

id_target=$(echo $hex_part | xxd -r -p)

echo $id_target

}
##-------------------------------------------



TmpDir=/tmp/GenTargets
TDir="$TmpDir/Targets"
DDir="$TmpDir/Destroy"
TmpDirWork="/home/dev/kr_vko"
DBDir="$TmpDirWork/db"
tact=0
>"$DBDir/readtargets"
>"$DBDir/status_targets"
>"$DBDir/status2_targets"
while true
do
listtarget=$(ls -tr $TDir | tail -n 50)
for target in $listtarget
do
if grep -q "$target" "$DBDir/readtargets"; then
continue
else
echo "$target">>"$DBDir/readtargets"
id_target=$(decrypt_filename "$target")
cat "$TDir/$target"

if grep -q "$id_target" "$DBDir/status_targets"; then
###
if grep -q "$id_target" "$DBDir/status2_targets"; then
###
continue
###
else
status="$(cat "$TDir/$target")"
id_target+=" "
id_target+="$status"
echo "$id_target">>"$DBDir/status2_targets"
fi


###
else
status="$(cat "$TDir/$target")"
id_target+=" "
id_target+="$status"
echo "$id_target">>"$DBDir/status_targets"
fi


fi
done



echo "tact: $tact"
sleep 0.5
tact=$((tact + 1))
done

