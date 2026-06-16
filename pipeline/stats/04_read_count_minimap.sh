#!/usr/bin/env bash
#SBATCH --nodes 1 --ntasks 1 -c 24 --mem 24G -p short -J readCount --out logs/minimap_ONT.%a.log --time 2:00:00
module load minimap2
module load samtools
module load mosdepth
module load workspace/scratch

hostname
MEM=24
CPU=$SLURM_CPUS_ON_NODE
N=${SLURM_ARRAY_TASK_ID}

if [ ! $N ]; then
    N=$1
    if [ ! $N ]; then
        echo "Need an array id or cmdline val for the job"
        exit
    fi
fi
IFS=,
SAMPLES=samples.csv
INDIR=data
ASM=genomes
OUTDIR=$(realpath mapping_report)

mkdir -p $OUTDIR/mosdepth
tail -n +2 $SAMPLES | sed -n ${N}p | while read ID FILEBASE SRARUN SPECIES STRAIN TAXONID LOCUSTAG BIOPROJECT BIOSAMPLE BUSCO NOTES
do

    FASTQ=$(realpath $INDIR/Nanopore/$NANOPORE)
    for type in canu flye
    do
    BASE=$STRAIN.$type.pilon
    SORTED=$(realpath $ASM/$BASE.fasta)
    if [ ! -f $SORTED ]; then
        echo "No $SORTED file for $ASM/$BASE.fasta"
        continue
    elif [ ! -s $OUTDIR/${BASE}.minimap.bam ]; then
        minimap2 -t $CPU -ax map-ont -o $SCRATCH/${BASE}.minimap.sam $SORTED $FASTQ
        samtools sort --threads $CPU -O BAM -o $OUTDIR/$BASE.minimap.bam -T $SCRATCH/$BASE $SCRATCH/${BASE}.minimap.sam
        samtools index $OUTDIR/$BASE.minimap.bam
    fi
    if [ ! -f $OUTDIR/mosdepth/$BASE.minimap.mosdepth.summary.txt ]; then
        mosdepth -t $CPU -n $OUTDIR/mosdepth/$BASE $OUTDIR/$BASE.minimap.bam
    fi
    done
done
