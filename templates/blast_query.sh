#!/bin/bash
set -e
set -u

type=`readlink -f !{query}`
file_size=`stat --printf="%s" !{query}`
block_size=$(( file_size / !{task.cpus} / 2 ))
if [[ ${type} == *"blast/primers"* ]]; then
    mkdir -p blast/primers
    cat !{query} |
    parallel --gnu --plain -j !{task.cpus} --block ${block_size} --recstart '>' --pipe \
    blastn -db !{sample} \
           -outfmt \'!{params.outfmt}\' \
           -dust no \
           -word_size 7 \
           -perc_identity !{params.perc_identity} \
           -evalue 1 \
           -query - > blast/primers/!{query_name}.txt

    if [[ !{params.compress} == "true" ]]; then
        pigz -n --best -p !{task.cpus} blast/primers/!{query_name}.txt
    fi
elif [[ ${type} == *"blast/proteins"* ]]; then
    mkdir -p blast/proteins
    cat !{query} |
    parallel --gnu --plain -j !{task.cpus} --block ${block_size} --recstart '>' --pipe \
    tblastn -db !{sample} \
            -outfmt \'!{params.outfmt}\' \
            -evalue 0.0001 \
            -qcov_hsp_perc !{params.qcov_hsp_perc} \
            -query - > blast/proteins/!{query_name}.txt

    if [[ !{params.compress} == "true" ]]; then
        pigz -n --best -p !{task.cpus} blast/proteins/!{query_name}.txt
    fi
else
    mkdir -p blast/genes
    cat !{query} |
    parallel --gnu --plain -j !{task.cpus} --block ${block_size} --recstart '>' --pipe \
    blastn -db !{sample} \
           -outfmt \'!{params.outfmt}\' \
           -task blastn \
           -evalue 1 \
           -perc_identity !{params.perc_identity} \
           -qcov_hsp_perc !{params.qcov_hsp_perc} \
           -query - > blast/genes/!{query_name}.txt

    if [[ !{params.compress} == "true" ]]; then
        pigz -n --best -p !{task.cpus} blast/genes/!{query_name}.txt
    fi
fi
