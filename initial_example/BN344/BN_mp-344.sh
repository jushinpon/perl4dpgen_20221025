#!/bin/sh
#sed_anchor01
#SBATCH --output=BN_mp-344.sout
#SBATCH --job-name=scf_BN_mp-344
#SBATCH --nodes=1
#SBATCH --partition=24Cores


export LD_LIBRARY_PATH=/opt/mpich-3.4.2/lib:/opt/intel/mkl/lib/intel64:$LD_LIBRARY_PATH
export PATH=/opt/mpich-3.4.2/bin:$PATH
#sed_anchor02
mpiexec /opt/QEGCC_MPICH3.4.2/bin/pw.x -in BN_mp-344.in



#squeue       # qstat
#scancel  1   # Delete JOB NO. 1 
#scontrol show job 1  # Check job NO.1 detail



################################################## DEBUG
#yum install dos2unix  #######   install this when you got as follows error messages
#sbatch: error: Batch script contains DOS line breaks (\r\n)
#sbatch: error: instead of expected UNIX line breaks (\n).
#dos2unix filename 
