#!/bin/bash

# Making dictionary using librispeech data with morpheme analysis.
# from the one in Kaldi s5 recipe in that it uses lower-case --Arnab (Jan 2013)

# To be run from one directory above this script.

. path.sh

#check existing directories
[ $# != 0 ] && echo "Usage: local/librispeech_data_prep.sh" && exit 1;

srcdir=data/train
dir=data/local/dict_nosp
mkdir -p $dir

sort -n librispeech/librispeech-lexicon.txt | uniq > librispeech/lexicon.txt
srcdict=librispeech/lexicon.txt

# assume data_prep.sh was done already.
[ ! -f "$srcdict" ] && echo "No such file $srcdict" && exit 1;

#(2a) Dictionary preparation:
# Pre-processing (Upper-case, remove comments)
cat $srcdict > $dir/lexicon1.txt || exit 1;

cat $dir/lexicon1.txt | awk '{ for(n=2;n<=NF;n++){ phones[$n] = 1; }} END{for (p in phones) print p;}' | \
  grep -v sp > $dir/nonsilence_phones.txt  || exit 1;

#( echo sil; echo spn; echo nsn; echo lau ) > $dir/silence_phones.txt
( echo sp ; echo spn ; ) > $dir/silence_phones.txt

echo sp > $dir/optional_silence.txt

# No "extra questions" in the input to this setup, as we don't
# have stress or tone.
echo -n >$dir/extra_questions.txt

# Add to the lexicon the silences, noises etc.
( echo '<sp> sp' ; echo '<UNK> spn'; ) | cat - $dir/lexicon1.txt  > $dir/lexicon2.txt || exit 1;


pushd $dir >&/dev/null
ln -sf lexicon2.txt lexicon.txt
popd >&/dev/null

echo Prepared input dictionary and phone-sets for librispeech phase 1.
