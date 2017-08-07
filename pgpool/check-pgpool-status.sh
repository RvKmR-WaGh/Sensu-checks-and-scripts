#!/bin/bash
# Author: Ravikumar Wagh <wagh1.ravi@gmail.com>

# set defaults
HOST="localhost"
PORT="9898"
USERNAME="postgres"
CRIT="100"
WARN="70"
PCPPASS_FILE="/opt/sensu/.pcppass"

function usage() {
    echo  "Usage:"
    echo  "-h HOST"
    echo  "-p PORT"
    echo  "-u USERNAME"
    echo  "-c CRIT in %"
    echo  "-w WARN in %"
}


function check_pcp_nodes_status() {
    NODES_DOWN=0;
    NODE_COUNT=$(PCPPASSFILE="$PCPPASS_FILE" /usr/sbin/pcp_node_count -h $1 -p $2 -U $3 -w)
    for (( n = 0; n < $NODE_COUNT; n++ ))
    do
        PCP_INFO_OUTPUT=$(PCPPASSFILE="$PCPPASS_FILE" /usr/sbin/pcp_node_info -h $1 -p $2 -w -U $3 $n)
        echo $PCP_INFO_OUTPUT
        if [[ $(echo $PCP_INFO_OUTPUT | awk '{print $3}') -gt 2 ]]; then
            NODES_DOWN=$(( NODES_DOWN + 1 ))
        fi
    done

    PERCENTAGE_NODES_DOWN=$(( NODES_DOWN * 100 / NODE_COUNT ))

    if [[ $PERCENTAGE_NODES_DOWN -ge $4 ]]; then
        echo "Critical: $PERCENTAGE_NODES_DOWN% of the nodes are down $NODES_DOWN/$NODE_COUNT"
        exit 2
    elif [[ $PERCENTAGE_NODES_DOWN -ge $5 ]]; then
        echo "Warning: $PERCENTAGE_NODES_DOWN% of the nodes are down $NODES_DOWN/$NODE_COUNT"
        exit 1
    else
        echo "OK: All nodes are up."
        exit 0
    fi
}


while getopts 'h:p:u:c:w:' opts
do
    case $opts in
        h)
            HOST="$OPTARG";;
        p)
            PORT="$OPTARG";;
        u)
            USERNAME="$OPTARG";;
        c)
            CRIT="$OPTARG";;
        w)
            WARN="$OPTARG";;
        *)
            usage; exit 1;;
    esac
done
if [[ -f "$PCPPASS_FILE" ]]; then
    check_pcp_nodes_status $HOST $PORT $USERNAME $CRIT $WARN
else
    echo "PCP password file not found, exiting..."
    exit 1
fi
