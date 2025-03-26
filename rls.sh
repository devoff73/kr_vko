#!/bin/bash

config_file=$1
rls_num=$2
file_log=$3
message_rls=$4
delim=":"
targets_dir="/tmp/GenTargets/Targets/"



if [ -f "$config_file" ]; then
    x0=$(grep -E "$rls_num$delim" "$config_file" -A 5 | grep 'x0:' | awk '{print $2}')
    y0=$(grep -E "$rls_num$delim" "$config_file" -A 5 | grep 'y0:' | awk '{print $2}')
    az=$(grep -E "$rls_num$delim" "$config_file" -A 5 | grep 'az:' | awk '{print $2}')
    ph=$(grep -E "$rls_num$delim" "$config_file" -A 5 | grep 'ph:' | awk '{print $2}')
    r=$(grep -E "$rls_num$delim" "$config_file" -A 5 | grep 'r:' | awk '{print $2}')
else
    echo "Файл $config_file не найден."
    exit 1
fi



function InRlsZone()
{
    local dx=$1
    local dy=$2
    local R=$3
    local AZ=$4
    local PH=$5

    local r=$(echo "sqrt ( (($dx*$dx+$dy*$dy)) )" | bc -l)
    r=${r/\.*}

    if (( $r <= $R ))
    then
        local phi=$(echo | awk " { x=atan2($dy,$dx)*180/3.14; print x}")
        phi=(${phi/\,*})
        check_phi=$(echo "$phi < 0"| bc)
        if [[ "$check_phi" -eq 1 ]]
        then
            phi=$(echo "360 + $phi" | bc)
        fi
        let phiMax=$AZ+PH/2
        let phiMin=$AZ-PH/2

        check_phiMax=$(echo "$phi <= $phiMax"| bc)
        check_phiMin=$(echo "$phi >= $phiMin"| bc)
        if (( $check_phiMax == 1 )) && (( $check_phiMin == 1 ))
        then
            return 1
        fi
    fi
    return 0
}


function Speedometer()
{
    local v=$1
    res=$(echo "$v>=8000  && $v<=10000 "| bc -l)
    if [ $res -eq 1 ]
    then
        return 1
    fi
    return 0
}

function ToSproDirection()
{
    local vx=$1
    local vy=$2
    local dx=$3
    local dy=$4
    local R=$5

    local r=$(echo "sqrt ( (($dx*$dx+$dy*$dy)) )" | bc -l)
    local v=$(echo "sqrt ( (($vx*$vx+$vy*$vy)) )" | bc -l)

    cos=$(echo "($vx*$dx + $vy*$dy) / ($r * $v)" | bc -l)
    b=$(echo "$r * sqrt(1 - $cos * $cos)" | bc -l)
    res=$(echo "$b <= $R && $cos > 0" | bc -l)
    if [ $res -eq 1 ]
    then
        return 1
    fi
    return 0
}

function decrypt_filename()
{
    local filename="$1"
    local interleaved="${filename:0:-2}"
    local hex_part=""

    for((i=0; i<${#interleaved}; i+=4)); do
    hex_part+="${interleaved:$i+2:2}"
    done

    id_target=$(echo $hex_part | xxd -r -p)

    echo $id_target
}

while :
do
    for file in `ls $targets_dir -t 2>/dev/null | head -30`
    do
        x=`cat 7a3975336a36633349664c61376276 | awk '{print $2}'`
        y=`cat 7a3975336a36633349664c61376276 | awk '{print $4}'`
        id=$(decrypt_filename "$file")
        let dx=$x0-$x
        let dy=$y0-$y

        
        # проверка наличия цели в области видимости рлс
        InRlsZone $dx $dy $r $az $ph
        targetInZone=$?

        if [[ $targetInZone -eq 1 ]]
        then
            # проверка наличия в файле этой цели
            str=$(tail -n 30 $file_log | grep $id | tail -n 1)
            num=$(tail -n 30 $file_log | grep -c $id)

            if [[ $num == 0 ]]
            then
                # echo "Обнаружена цель ID: $id" >> $message_rls
                echo "$id $x $y rls: $rls_num" >> $file_log

            else
                x1=$(echo "$str" | awk '{print $2}')
                y1=$(echo "$str" | awk '{print $3}')
                let vx=x-x1
                let vy=y-y1
                v=$(echo "sqrt ( (($vx*$vx+$vy*$vy)) )" | bc -l)

                # проверка, что цель - БР
                Speedometer $v
                SpeedometerResult=$?
                if [[ $SpeedometerResult -eq 1 ]]
                then
                    let dx=$x0-$x1
                    let dy=$y0-$y1

                    # проверка, что цель летит в сторону спро
                    ToSproDirection $vx $vy $dx $dy $r
                    ToSproDirectionResult=$?
                    if [[ $ToSproDirectionResult -eq 1 ]]
                    then
                        # проверка что БР, летящая к спро обнаружена
                        check=$(cat $message_rls | grep "$id")
                        if [ -z "$check" ]
                        then
                            echo "`date -u` $rls_num $id $x $y: БР движется в направлении СПРО" >> $message_rls
                        fi
                    else
                        check=$(cat $message_rls | grep "$id")
                        if [ -z "$check" ]
                        then
                            echo "`date -u` $rls_num $id $x $y: обнаружена БР" >> $message_rls
                        fi
                    fi
                fi
            fi
        fi
    done

    sleep 0.5
done