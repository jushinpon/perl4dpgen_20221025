use warnings;
use strict;
use JSON::PP;
use Data::Dumper;
use Cwd;
use POSIX;
use Parallel::ForkManager;

sub matplot{

my ($ss_hr,$dps_hr) = @_;
my $mainPath = $ss_hr->{main_dir};# main path of dpgen folder
my $currentPath = $ss_hr->{script_dir};
my $debug = $ss_hr->{debug};
my $trainNo = $ss_hr->{trainNo};
my $working_dir = $dps_hr->{working_dir};#training folder
my $npydir4matplot = "$mainPath/matplot";
my $npy_dirs = "$mainPath/all_npy*";#you may use your dir, under which all npy files are included.

$ss_hr->{iter} =~ s/^\s+|\s+$//;#could be "initial dp train" or integer
my $iter;
if ($ss_hr->{iter} =~ /^-?\d+\.?\d*$/){
    $iter = "iter". sprintf("%03d",$ss_hr->{iter});
}
else{
    $iter = "initial";
}
###arrange npy files

my @temp = `find $npy_dirs  -type d -name "set.*"`;#all npy files, also within /val
die "no npy files in all_npy* folders folders\n" unless(@temp);
map { s/^\s+|\s+$//g; } @temp;
my @allnpy_temp; # dirs with all set.XXX folders
for (0..$#temp){
    my $temp = `dirname $temp[$_]`;
    chomp $temp;
    $allnpy_temp[$_] = $temp;#remove the last set.XX
   # print "$allnpy[$_]\n";
}

my %temp = map {$_ => 1} @allnpy_temp;
my @allnpy = sort keys %temp; # dirs with all set.XXX folders
map { s/^\s+|\s+$//g; } @allnpy;
my $allnpyNo = @allnpy;

my @allnpy4train;
my @allnpy4valid;

#keep the information of training and validation data
`rm -f ../matplot/train_dir__$iter.txt`; 
`rm -f ../matplot/valid_dir__$iter.txt`; 
`touch ../matplot/train_dir__$iter.txt`; 
`touch ../matplot/valid_dir__$iter.txt`;
#
for (@allnpy){
    chomp;
    if(/.+\/val$/){
        push @allnpy4valid, $_;#npy for validation
        `echo $_ >> ../matplot/valid_dir__$iter.txt`;
    }
    else{
        push @allnpy4train, $_;#npy for training
        `echo $_ >> ../matplot/train_dir__$iter.txt`;
    }
}
die "No val npy files for validation\n" unless(@allnpy4valid);
die "No trainning npy files\n" unless(@allnpy4train);

my $train_dir = "$npydir4matplot/train_npy";#collect all training npys
my $validation_dir = "$npydir4matplot/validation_npy";

`rm -rf $train_dir`;
`mkdir -p $train_dir`;
`rm -rf $validation_dir`;
`mkdir -p $validation_dir`;

for (0..$#allnpy4train){#copy training npy files
    chomp;
    chomp $allnpy4train[$_];
    my @temp = `find $allnpy4train[$_] -maxdepth 1 -type d -name "set.*"`;#all npy files
    map { s/^\s+|\s+$//g; } @temp;
    for my $t (@temp){
        $t =~ /.+set\.(.+)$/;
        chomp $1;
        #print "\$1: $1\n";
        `mkdir -p $train_dir/$_/$1`;
        `cp -r $t $train_dir/$_/$1`;
        `cp  $allnpy4train[$_]/type.raw $train_dir/$_/$1`;
        `cp  $allnpy4train[$_]/box.raw$1 $train_dir/$_/$1/box.raw`;
        `cp  $allnpy4train[$_]/coord.raw$1 $train_dir/$_/$1/coord.raw`;
        `cp  $allnpy4train[$_]/energy.raw$1 $train_dir/$_/$1/energy.raw`;
        `cp  $allnpy4train[$_]/force.raw$1 $train_dir/$_/$1/force.raw`;
    }
}

for (0..$#allnpy4valid){#copy validation npy files
    chomp;
    `rm -r $validation_dir/$_`;
    `mkdir -p $validation_dir/$_`;
    `cp -r $allnpy4valid[$_] $validation_dir/$_`;
}

##########
#my $forkNo = $trainNo;# $trainNo;
#my $pm = Parallel::ForkManager->new("$forkNo");

my @make_plots = ("train","validation");

for (1..$trainNo){
    #$pm->start and next;
    my $temp = sprintf("%02d",$_);
    chomp $temp;
    `rm ./lcurve.out`;#remove old lcurve.out in current dir 
    `cp  $mainPath/dp_train/graph$temp/lcurve.out ./`;#for loss profiles
    `cp  $mainPath/dp_train/graph$temp/lcurve.out ../matplot_data/lcurve_$iter-graph$temp.out`;#for raw data

    for (0..$#make_plots){
        `rm ./temp.*.out`;#remove old dp test output files in current dir 
        `rm ./tempmod.*.out`;#remove old dp test output files in current dir 
       
        #the following for check pred. and ref. data distributions for energy, force, and virial 
        my $source = "$npydir4matplot/$make_plots[$_]"."_npy"; 

        system("source activate deepmd-cpu;dp test -n 100000 -m $mainPath/dp_train/graph$temp/graph$temp.pb -s $source -d ./temp.out -v 0 2>&1 >/dev/null;conda deactivate");
# get atom number for normalizing energy
        `cp  ./temp.e.out ../matplot_data/$make_plots[$_]-Oritemp.e_$iter-graph$temp.out`;#for raw data
        `cp  ./temp.f.out ../matplot_data/$make_plots[$_]-temp.f_$iter-graph$temp.out`;#for raw data
        `cp  ./temp.v.out ../matplot_data/$make_plots[$_]-temp.v_$iter-graph$temp.out`;#for raw data

        `mv ./temp.e.out ./tempmod.e.out`;# for the following touch temp.e.out
        #check the required minimum number 
        my @temp = `grep "#" ./tempmod.e.out|awk '{print \$2}'`;
        die "No energy listed in temp.e.out after dp test" unless(@temp);
        map { s/^\s+|\s+$//g; } @temp;
        my $energyNo = @temp;
        if($energyNo == 1){
            print "Currently, only one reference energy in temp.e.out after dp test",
            " python script doesn't work if the energy number is 1. No png file is plotted.\n";
            last;
        }

        my @npypath = map {$_ =~ s/:$//g; $_;} @temp;#remove ":"
        die "no npy dirs for matplot\n" unless(@npypath);
        #chomp @npypath;
        my @atomNo;
        for my $npath (@npypath){
            #$_ =~ s/:$//g;
            #print "path: $_\n";
            my @temp = `cat $npath/coord.raw`;#get how many frames in this raw
            map { s/^\s+|\s+$//g; } @temp;
            for my $nu (@temp){
                $nu  =~ s/^\s+|\s+$//;
                my @sp = split(/\s+/,$nu);
                map { s/^\s+|\s+$//g; } @sp;
                my $num = @sp/3;
                push @atomNo,$num;
            }
        }
        my @tempdata = `grep -v "#" ./tempmod.e.out`;
        map { s/^\s+|\s+$//g; } @tempdata;
        my @data = grep (($_!~m{^\s*$|^#}),@tempdata); # remove blank elements
        my $dataNo = @data;
        my $atomarrayNo = @atomNo;
        die "the data number and atom number array are not equal\n" if($dataNo != $atomarrayNo);
        `touch ./temp.e.out`;
        for my $dt (0..$#data){
            $data[$dt]  =~ s/^\s+|\s+$//;
            #print "\$data[\$dt]: $data[$dt]\n";
            my @temp = split(/\s+/,$data[$dt]);
            chomp @temp;
            #print "dt: $dt, $temp[0] $temp[1]\n";
            $temp[0] = $temp[0]/$atomNo[$dt];
            $temp[1] = $temp[1]/$atomNo[$dt];
            #chmop @temp;
            `echo "$temp[0] $temp[1]" >> ./temp.e.out`;
        }
        `cp  ./temp.e.out ../matplot_data/$make_plots[$_]-temp.e_$iter-graph$temp.out`;#for raw data

# end of energy normalization    
        system ("python dp_plots.py");
        sleep(1);
        `mv ./dp_temp.png $mainPath/matplot/00$make_plots[$_]-iter_$iter-graph$temp.png`;    
    #$pm-> finish;
    }#train and validation loops
}
#$pm->wait_all_children;

#housekeeping
`rm ./lcurve.out`;#remove old lcurve.out in current dir 
`rm ./temp.*.out`;#remove old dp test output files in current dir
`rm ./tempmod.*.out`;#remove old dp test output files in current dir

#/dp_train/graph01/lcurve.out;
#
#cp ../dp_train/graph01/lcurve.out
#`rm -f test0503*`;
#system("source activate deepmd-cpu;dp test -m /home/jsp/Perl4dpgen/dp_train/graph01/graph01.pb -s /home/jsp/Perl4dpgen/matplot -d test0503.out");
#`python plot_e.py`;
##dp test -m /home/jsp/Perl4dpgen/dp_train/graph01/graph01.pb -s /home/jsp/Perl4dpgen/all_npysoft  -d testnew.out
##
##dp test -m /home/jsp/Perl4dpgen/dp_train/graph01/graph01.pb -s /home/jsp/Perl4dpgen/matplot  -d testnew.out

}# end sub
1;