#!/usr/bin/env perl
# In Arabic PUD, finds the LId attribute in MISC, assuming that it contains
# Buckwalter encoding (including '|'!) Converts it to the Arabic script.
# Copyright © 2022 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

# Tabulka korespondence Buckwalterových znaků, arabských písmen a vědecké transkripce podle Elixiru (která zřejmě odpovídá DIN 31635).
@buckwalter =
(
    ['A', "\x{627}", 'ʾ'], # alef ʾ / ā
    ['b', "\x{628}", 'b'], # beh
    ['t', "\x{62A}", 't'], # teh
    ['v', "\x{62B}", 'ṯ'], # theh
    ['j', "\x{62C}", 'ǧ'], # jeem
    ['H', "\x{62D}", 'ḥ'], # hah
    ['x', "\x{62E}", "\x{1E2B}"], # khah ḫ
    ['d', "\x{62F}", 'd'], # dal
    ['*', "\x{630}", 'ḏ'], # thal (dh)
    ['r', "\x{631}", 'r'], # reh
    ['z', "\x{632}", 'z'], # zain
    ['s', "\x{633}", 's'], # seen
    ['$', "\x{634}", 'š'], # sheen
    ['S', "\x{635}", 'ṣ'], # sad
    ['D', "\x{636}", 'ḍ'], # dad
    ['T', "\x{637}", 'ṭ'], # tah
    ['Z', "\x{638}", 'ẓ'], # zah
    ['E', "\x{639}", 'ʿ'], # ain
    ['g', "\x{63A}", 'ġ'], # ghain
    ['f', "\x{641}", 'f'], # feh
    ['q', "\x{642}", 'q'], # qaf
    ['k', "\x{643}", 'k'], # kaf
    ['l', "\x{644}", 'l'], # lam
    ['m', "\x{645}", 'm'], # meem
    ['n', "\x{646}", 'n'], # noon
    ['h', "\x{647}", 'h'], # heh
    ['w', "\x{648}", 'w'], # waw w / ū
    ['y', "\x{64A}", 'y'], # yeh
    ['Y', "\x{649}", 'ī'], # alef maksura
    ["'", "\x{621}", 'ʾ'], # hamza
    ['>', "\x{623}", 'ʾa'], # hamza on alif
    ['<', "\x{625}", 'ʾi'], # hamza below alif
    ['&', "\x{624}", 'ʾu'], # hamza on wa
    ['}', "\x{626}", 'ʾi'], # hamza on ya
    ['|', "\x{622}", 'ʾā'], # madda on alif
    ['{', "\x{671}", 'ā'], # alif al-wasla
    ['`', "\x{670}", 'ā'], # dagger alif; not sure what it is, used superscript alef
    ['a', "\x{64E}", 'a'], # fatha
    ['u', "\x{64F}", 'u'], # damma
    ['i', "\x{650}", 'i'], # kasra
    ['F', "\x{64B}", 'an'], # fathatan
    ['N', "\x{64C}", 'un'], # dammatan
    ['K', "\x{64D}", 'in'], # kasratan
    ['~', "\x{651}", '~'], # shadda; for Elixir transliteration we would need s/(.)~/$1$1/g but we cannot encode it using this table
    ['o', "\x{652}", ''], # sukun
    ['p', "\x{629}", 'ât'], # teh marbuta
    ['_', "\x{640}", ''], # tatweel
    ['0', "\x{660}", '0'],
    ['1', "\x{661}", '1'],
    ['2', "\x{662}", '2'],
    ['3', "\x{663}", '3'],
    ['4', "\x{664}", '4'],
    ['5', "\x{665}", '5'],
    ['6', "\x{666}", '6'],
    ['7', "\x{667}", '7'],
    ['8', "\x{668}", '8'],
    ['9', "\x{669}", '9'],
);

my %prevod;
my $maxl = inicializovat(\%prevod);
while(<>)
{
    if(m/^[0-9]/)
    {
        s/\r?\n$//;
        my @f = split(/\t/);
        my $misc = $f[9];
        # We cannot split the MISC column on '|' as usual because this character
        # may be part of the Buckwalter string in LId.
        if($misc =~ s/LId=(.+)(_[0-9]+)/LId=$2/)
        {
            my $buck = $1;
            my $arab = prevest(\%prevod, $buck, $maxl);
            $misc =~ s/LId=/LId=$arab/;
        }
        $f[9] = $misc;
        $_ = join("\t", @f)."\n";
    }
    print;
}



#------------------------------------------------------------------------------
# Uloží do hashe přepisy Buckwalterových znaků. Odkaz na cílový hash převezme
# jako parametr. Vrátí délku nejdelšího řetězce, jehož přepis je v hashi
# definován.
#------------------------------------------------------------------------------
sub inicializovat
{
    # Odkaz na hash, do kterého se má ukládat převodní tabulka.
    my $prevod = shift;
    my $maxl;
    ###!!! Přepis z Buckwaltera do Elixiru zatím nelze zapnout, i když přibližnou tabulku nahoře nachystanou máme.
    foreach my $radek (@buckwalter)
    {
        my $buck = $radek->[0];
        my $utf = $radek->[1];
        $prevod->{$buck} = $utf;
        my $l = length($buck);
        $maxl = $l if($l>$maxl);
    }
    return $maxl;
}



#------------------------------------------------------------------------------
# Converts a string from one script or encoding to another. Before calling this
# function, we have to initialize the transliteration table (hash) in the
# respective module. This function does not restrict the length of the substring
# whose transliteration can be defined in the hash, but it does not scan the
# hash to figure out the maximal length (it would not be efficient; this
# function may be called separately for each word, million times in a row).
# Instead, one may to figure out the maximal length beforehand and give it to
# the function as a parameter. Without the parameter, the function will use a
# default value.
#------------------------------------------------------------------------------
sub prevest
{
    my $prevod = shift; # reference to the hash with the transliteration table
    my $retezec = shift;
    my $maxl = shift; # maximum possible length of the source substring
    $maxl = 5 unless($maxl); # default maximum length
    my $vysledek;
    my @chars = split(//, $retezec);
    my $l = scalar(@chars);
    for(my $i = 0; $i<=$#chars; $i++)
    {
        $maxl = $l-$i if($i+$maxl>$l);
        for(my $j = $maxl; $j>0; $j--)
        {
            my $usek = join('', @chars[$i..($i+$j-1)]);
            if(exists($prevod->{$usek}))
            {
                $vysledek .= $prevod->{$usek};
                $i += $j-1;
                last;
            }
            # If no transliteration is available for the current character, copy the character to the output.
            elsif($j==1)
            {
                $vysledek .= $usek;
            }
        }
    }
    return $vysledek;
}
