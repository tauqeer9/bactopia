#!/bin/bash
set -e
set -u

if [ "!{params.dry_run}" == "true" ]; then
    mkdir -p mapping
    touch mapping/!{query_name}.coverage.txt
else
    avg_len=`seqtk fqchk !{fq[0]} | head -n 1 | sed -r 's/.*avg_len: ([0-9]+).*;.*/\1/'`
    bwa index !{query}
    if [ "${avg_len}" -gt "70" ]; then
        bwa mem -M -t !{task.cpus} !{bwa_mem_opts} !{query} !{fq} > bwa.sam
    else
        if [ "!{single_end}" == "true" ]; then
            bwa aln -f bwa.sai -t !{task.cpus} !{bwa_aln_opts} !{query} !{fq[0]}
            bwa samse -n !{params.bwa_n} !{bwa_samse_opts} !{query} bwa.sai !{fq[0]} > bwa.sam
        else
            bwa aln -f r1.sai -t !{task.cpus} !{bwa_aln_opts} !{query} !{fq[0]}
            bwa aln -f r2.sai -t !{task.cpus} !{bwa_aln_opts} !{query} !{fq[1]}
            bwa sampe -n !{params.bwa_n} !{bwa_sampe_opts} !{query} r1.sai r2.sai !{fq[0]} !{fq[1]} > bwa.sam
        fi
    fi
    samtools view !{f_value} -bS bwa.sam | samtools sort -o !{query_name}.bam -

    # Write per-base coverage
    samtools view -bS bwa.sam | samtools sort -o cov_only.bam -
    genomeCoverageBed -ibam cov_only.bam -d > cov.txt
    echo "##contig=<ID=$(head -n1 cov.txt|cut -f1),length=$(wc -l cov.txt|cut -f1 -d' ')>" > !{query_name}.coverage.txt
    cut -f3 cov.txt >> !{query_name}.coverage.txt
    rm cov.txt cov_only.bam

    if [[ !{params.compress} == "true" ]]; then
        pigz --best -n -p !{task.cpus} !{query_name}.coverage.txt
    fi

    mkdir -p mapping/!{query_name}
    mv !{query_name}.bam !{query_name}.coverage.txt* mapping/!{query_name}
    rm bwa.sam
fi
