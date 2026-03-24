#!/usr/bin/bash -l
#SBATCH -p short -c 48 -N 1 -n 1 --mem 48G --out logs/annotate_mask.%a.log

module unload miniconda3

CPU=1
if [ -n "$SLURM_CPUS_ON_NODE" ]; then
    CPU=$SLURM_CPUS_ON_NODE
fi

INDIR=genomes
RMODELER=RepeatModeler_run
OUTDIR=RepeatMasker_run
RMLIBFOLDER=library/repeat_library
mkdir -p $RMLIBFOLDER $OUTDIR
SAMPLEFILE=samples.csv
N=${SLURM_ARRAY_TASK_ID}

if [ -z $N ]; then
    N=$1
    if [ -z $N ]; then
        echo "need to provide a number by --array or cmdline"
        exit
    fi
fi
MAX=$(wc -l $SAMPLEFILE | awk '{print $1-1}')
if [ $N -gt $MAX ]; then
    echo "$N is too big, only $MAX samples in $SAMPLEFILE"
    exit
fi

IFS=,
tail -n +2 $SAMPLEFILE | sed -n ${N}p | while read ID FILEBASE SRARUN SPECIES STRAIN TAXONID LOCUSTAG BIOPROJECT BIOSAMPLE BUSCO NOTES
do
    echo "ID is $ID"
    name=$ID
    GENOME=$(realpath $INDIR/${name}.sorted.fasta)
    MASKED=$INDIR/${name}.masked.fasta
    LIBRARY=$(realpath -m $RMLIBFOLDER/$ID.repeatmodeler.lib)
    STKLIBRARY=$(realpath -m $RMLIBFOLDER/$ID.repeatmodeler.stk)

    if [ ! -s $MASKED ]; then
        if [ ! -f $OUTDIR/${name}/${name}.sorted.fasta.masked ]; then
            if [ ! -f $LIBRARY ]; then
                module load RepeatModeler
                mkdir -p $RMODELER/${name}
                pushd $RMODELER/${name}
                #rm -rf RM_*
                BuildDatabase -name $ID $GENOME
                RepeatModeler -threads $CPU -database $ID -LTRStruct
                rsync -a ${ID}-families.fa $LIBRARY
                rsync -a ${ID}-families.stk $STKLIBRARY
                popd
            fi
        fi
        if [ -s $LIBRARY ]; then
            module load RepeatMasker
            RepeatMasker -e ncbi -xsmall -s -pa $CPU -lib $LIBRARY -dir $OUTDIR/$ID -gff $GENOME
        fi
        rsync -a $OUTDIR/${name}/${name}.sorted.fasta.masked $MASKED
    else
        echo "Skipping ${name} as masked file $MASKED already exists"
    fi
done
