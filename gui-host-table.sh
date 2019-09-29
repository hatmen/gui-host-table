#!/bin/bash
# author: hatmen

declare -A host_array
host_file='./host-info.conf'
p_size=10
p_start=0
p_end=${p_size}

function logger {
    case $1 in
        WARN|warn)
            shift
            echo -e "\033[33m WARN:$@ \033[0m"
            ;;
        INFO|info)
            shift
            echo -e "\033[34m INFO:$@ \033[0m"
            ;;
        ERROR|error)
            shift
            echo -e "\033[31m ERROR:$@ \033[0m"
            ;;
        *)
            echo -e "\033[34m INFO:$@ \033[0m"
            ;;
    esac
}

function analysis_config {
    host_array=()
    message=$1
    n=1
    # search message
    if [[ -n ${msg} ]]; then
        lines=`grep -Ev "^$|^[#;]" $host_file|grep "$message"`
    else
        lines=`grep -Ev "^$|^[#;]" $host_file`
    fi

    # create host array
    if [[ -z $lines ]]; then
        logger ERROR "No host list found!"
        exit -1
    else
        for i in $lines; do
            num=`echo $i|awk -F: 'END{print NF}'`
            # check split
            if [[ $num -ne 5 ]];then
                logger error "Host configuration split is not equal to 5:" $num
            fi

            OIFS="${IFS}"
            IFS=":"
            read -r -a array <<< "$i"
            host_array[$n]=${array[@]}
            IFS=${OIFS}
            let n=$n+1
        done
    fi
}


function print_table {
    # table header
    header="%-5s %-15s %-15s %-20s\n"
    printf "$header" "ID" "Host" "User" "Context"
    printf "===================================================\n"

    # print host tables
    read -r -a host_entry <<< `echo ${!host_array[@]}|tr ' ' '\n'|sort -n`
    for key in ${host_entry[@]:$p_start:$p_end}; do
        line=(${host_array[$key]})
        printf "$header" "[$key]" ${line[1]} ${line[2]} "${line[4]}"
    done
    echo ""
}

function host_search {
    echo -n "Please add search content: "
    read msg
    analysis_config "$msg"
    print_table
}

function host_select {
    echo -n "Please select a serial number or option: "
    read option
    case ${option} in
        [1-9]*)
            connection ${option}
            ;;
        D|d)
            num=${#host_array[@]}
            if [[ $p_start -gt $num ]];then
                logger info "No host list found!"
            else
                p_start=$p_end
                let p_end=$p_start+$p_size
                print_table
            fi
            ;;
        A|a)
            if [[ $p_start -eq 0 ]]; then
                logger info "No host list found!"
            else
                oend=$p_end
                p_end=$p_start
                let START=$oend-$p_size
                print_table
            fi
            ;;
        S|s)
            host_search
            ;;
        R|r)
            p_start=0
            p_end=$p_size
            analysis_config
            print_table
            ;;
        exit|q|quit)
            exit 0
            ;;
        esac
}

function connection {
    index=$1
    host_info=${host_array[$index]}
    if [[ -z $host_info ]];then
        logger error "Serial number does not match!"
        exit -1
    fi
    read -r -a array <<< $host_info
    ssh_type=${array[0]}
    host=${array[1]}
    host_user=${array[2]}
    host_passwd=${array[3]}
    if [[ $ssh_type == "p" ]]; then
        sshpass -p $host_passwd ssh $host_user@$host
    elif [[ $ssh_type == "k" ]]; then
        ssh -i $host_passwd $host_user@$host
    else
        logger warn "The host type is incorrect. Please check the configuration."
    fi
}


function main {
    analysis_config
    print_table
    while /bin/true; do
        host_select
    done
}

clear
main
