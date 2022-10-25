##This module is developed by Prof. Shin-Pon JU at NSYSU on March 28 2021
package elements; 

use strict;
use warnings;

our (%element); # density (g/cm3), arrangement, mass, lat a , lat c

#$element{"N"} = [1.251,"hcp",14.007,3.861,6.265]; 
$element{"B"} = [2.46,"hcp",10.81,5.06,5.06]; 
$element{"N"} = [1.251,"hcp",14.007,2.86653.861,6.265]; 

sub eleObj {# return properties of an element
   my $elem = shift @_;
   if(exists $element{"$elem"}){
    return (@{$element{"$elem"}});      
   }
   else{
      die "element information of \"$_\" is not listed in elements.pm.",
      " You need to add Al according to the format of density (g/cm3), arrangement, mass, lat a , lat c. ",
      ' For example, $element{"Nb"} = [8.57,"bcc",92.90638,3.30,3.30]'."\n"; 
   }
}
1;               # Loaded successfully
