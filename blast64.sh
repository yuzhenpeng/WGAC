#!/bin/bash

# Run BLAST64 for the given input sequences.
#
# Usage: qsub -q all.q blast64.sh -i <INPUT> -o <OUTPUT> -b <BLASTDB>

# Specify the shell for this job
#$ -S /bin/bash

export MPICH_PROCESS_GROUP=no 
export P4_RSHCOMMAND=/usr/bin/rsh 
export JOBDIR=$TMPDIR/work

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib64/openmpi/1.4-gcc/lib
export PATH=$PATH:/usr/lib64/openmpi/1.4-gcc/bin
export PATH=/net/eichler/vol7/home/psudmant/local_installations/bin:$PATH
export MANPATH=$MANPATH:/usr/lib64/openmpi/1.4-gcc/man
export PYTHONPATH=/net/gs/vol2/home/psudmant/local_installations/lib/python2.6/site-packages:$PYTHONPATH

#$ -pe orte 10-30

# Send an email when the script begins, ends, aborts, or suspends.
#$ -m beas

#$ -l h_vmem=8G
#$ -l disk_free=4G

# The job is located in the current working directory.
#$ -cwd

echo "Got $NSLOTS slots"
echo "path=$PATH"
echo "P4_RSHCOMMAND=$P4_RSHCOMMAND"

WORKING_DIR=$SGE_O_WORKDIR
INPUT="$WORKING_DIR/fugu"
OUTPUT="$WORKING_DIR/blastout"
DATABASE_PATH="$WORKING_DIR/blastdb/bofugu"
BLAST_TMP_DIR=/var/tmp/blastdb

# Get options from the user.
while getopts :i:o:b:t: OPTION
do
  case $OPTION in
    i)
      INPUT=$OPTARG
      ;;
    o)
      OUTPUT=$OPTARG
      ;;
    b)
      DATABASE_PATH=$OPTARG
      ;;
    t)
      BLAST_TMP_DIR=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;      
  esac
done

# Get short name of the database.
DATABASE_NAME=`basename $DATABASE_PATH`

echo Database name: $DATABASE_NAME
echo Database path: $DATABASE_PATH
echo Tmp path: $BLAST_TMP_DIR
echo Input: $INPUT
echo Output: $OUTPUT

echo Copying files to nodes
# Create tmp directory on cluster nodes and copy BlastDB files to nodes.
mpirun -mca btl ^openib -np $NSLOTS \
  /net/eichler/vol4/home/jlhudd/src/rsync_mpi/rsync_mpi.py \
  "$DATABASE_PATH.[^q]*" "$BLAST_TMP_DIR" \
  --pre_sync_commands="mkdir -p $BLAST_TMP_DIR"

# Run BLAST.
echo Running BLAST
mpirun -mca btl ^openib \
  -np $NSLOTS \
  /net/eichler/vol4/home/jlhudd/bin/general_pipe \
  "/net/eichler/vol2/local/bin/blastall -p blastn -i dummy_in -o dummy_out -d $BLAST_TMP_DIR/$DATABASE_NAME -v 5000 -b 5000 -G 180 -E 1 -q -80 -r 30 -e 1e-30 -F F -z 3000000000 -Y 3000000000" \
  $INPUT $OUTPUT ".bo" $TMPDIR

echo Done

# Clean up.
#/usr/bin/uniq $TMPDIR/machines | /net/eichler/vol2/local/bin/rgang - rm -rf $BLAST_TMP_DIR


# blastall is v2.2.11, not much different than 2.2.20
# -p blastn (program name)
# -d /net/eichler/vol4/home/linchen2/wgac/GRCh37/blastdb/bofugu (database)

# -z 3000000000 (?? effective length of database, useful for maintaining consistent statistics as databases grow ??)
# -Y 3000000000 (?? effective length of the search space = db size * query ??)
# http://etutorials.org/Misc/blast/Part+V+BLAST+Reference/Chapter+13.+NCBI-BLAST+Reference/13.3+blastall+Parameters/

# -v 5000 (?? # of database seqs to show one-line descriptions)
# -b 5000 (# of database seqs to show alignments)

# -G 180 (gap open cost)
# -E 1 (gap extension cost)
# -q -80 (nuc mismatch penalty)
# -r 30 (nuc match reward)
# -e 1e-30 (e-value)
# -F F (don't filter query seq)
