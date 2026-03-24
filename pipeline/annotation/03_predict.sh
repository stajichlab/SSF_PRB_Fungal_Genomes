#!/usr/bin/bash -l
#SBATCH --time 3-0:00:00 --ntasks 16 --nodes 1 --mem 24G --out logs/annotate_predict.%a.log

# this will define $SCRATCH variable if you don't have this on your system you can basically do this depending on
# where you have temp storage space and fast disks
module load workspace/scratch

CPU=1
if [ $SLURM_CPUS_ON_NODE ]; then
    CPU=$SLURM_CPUS_ON_NODE
fi

INDIR=genomes
OUTDIR=annotation
mkdir -p $OUTDIR
SAMPLEFILE=samples.csv

N=${SLURM_ARRAY_TASK_ID}

if [ -z $N ]; then
    N=$1
    if [ -z $N ]; then
        echo "need to provide a number by --array or cmdline"
        exit
    fi
fi
MAX=$(wc -l $SAMPLEFILE | awk '{print $1}')

if [ $N -gt $MAX ]; then
    echo "$N is too big, only $MAX lines in $SAMPLEFILE"
    exit
fi

export AUGUSTUS_CONFIG_PATH=$(realpath lib/augustus/3.5.0/config)
export FUNANNOTATE_DB=/bigdata/stajichlab/shared/lib/funannotate_db

SEED_SPECIES=aspergillus_fumigatus
SEQCENTER=UMichigan
IFS=,
tail -n +2 $SAMPLEFILE | sed -n ${N}p
echo $SAMPLEFILE

tail -n +2 $SAMPLEFILE | sed -n ${N}p | while read ID FILEBASE SRARUN SPECIES STRAIN TAXONID LOCUSTAG BIOPROJECT BIOSAMPLE BUSCO NOTES
do
    echo "STRAIN is $STRAIN LOCUSTAG is $LOCUSTAG"
    name=$FILEBASE
    MASKED=$INDIR/$name.masked.fasta
    echo "masked is $MASKED"
    if [ ! -f $MASKED ]; then
        echo "no masked file $MASKED"
        exit
    fi
    module load funannotate
    funannotate predict --cpus $CPU --keep_no_stops --SeqCenter $SEQCENTER \
		--busco_db $BUSCO --optimize_augustus \
		--strain $STRAIN --min_training_models 100 \
		--AUGUSTUS_CONFIG_PATH $AUGUSTUS_CONFIG_PATH \
		-i $MASKED --name $LOCUSTAG \
		-s "$SPECIES" -o $OUTDIR/${name} --busco_seed_species $SEED_SPECIES
done
