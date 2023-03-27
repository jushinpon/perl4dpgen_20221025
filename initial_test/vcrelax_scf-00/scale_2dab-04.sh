#!/bin/sh
#sed_anchor01
#SBATCH --output=scale_2dab-04.sout
#SBATCH --job-name=scale_2dab-04
#SBATCH --nodes=1
#SBATCH --partition=C16M64_i912G 
##SBATCH --exclude=node30
#SBATCH --ntasks-per-node=16


export LD_LIBRARY_PATH=/opt/mpich-3.4.2/lib:/opt/intel/mkl/lib/intel64:$LD_LIBRARY_PATH
export PATH=/opt/mpich-3.4.2/bin:$PATH
#sed_anchor02
mpiexec /opt/QEGCC_MPICH3.4.2/bin/pw.x -in scale_2dab-04.in



#squeue       # qstat
#scancel  1   # Delete JOB NO. 1 
#scontrol show job 1  # Check job NO.1 detail



################################################## DEBUG
#yum install dos2unix  #######   install this when you got as follows error messages
#sbatch: error: Batch script contains DOS line breaks (\r\n)
#sbatch: error: instead of expected UNIX line breaks (\n).
#dos2unix filename 
