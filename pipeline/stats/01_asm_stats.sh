#!/usr/bin/env bash
#SBATCH -p short -N 1 -n 2 --mem 4gb --out logs/assess.log

module load AAFTF

IFS=,
SAMPLES=samples.csv
INDIR=asm
OUTDIR=genomes

mkdir -p $OUTDIR
tail -n +2 $SAMPLES | while read ID FILEBASE SRARUN SPECIES STRAIN TAXONID LOCUSTAG BIOPROJECT BIOSAMPLE BUSCO NOTES
do
    if [[ ! -s $OUTDIR/$ID.stats.txt || $OUTDIR/$ID.stats.txt -ot $OUTDIR/$ID.sorted.fasta ]]; then
        AAFTF assess -i $OUTDIR/$ID.sorted.fasta -r $OUTDIR/$ID.stats.txt
    fi
done
