#!/bin/bash

. ./cmd.sh
. ./path.sh
set -e # exit on error

# Set this to somewhere where you want to put your data, or where
# someone else has already put it.  You'll want to change this
# if you're not on the CLSP grid.
data=.
part=train-clean-100
[ -d $data/LibriSpeech/$part ] && `touch $data/LibriSpeech/$part/.complete`

# base url for downloads.
data_url=www.openslr.org/resources/12
lm_url=www.openslr.org/resources/11
local/download_and_untar.sh $data $data_url $part

orglibrispeech=librispeech

# データの下準備
mkdir -p $orglibrispeech/train
mkdir -p $orglibrispeech/eval1

fullpath=`readlink -f $data`
ln -sf $fullpath/LibriSpeech/SPEAKERS.TXT $orglibrispeech/SPEAKERS.TXT
ln -sf $fullpath/LibriSpeech/$part/19 $orglibrispeech/train/19
ln -sf $fullpath/LibriSpeech/$part/26 $orglibrispeech/train/26
ln -sf $fullpath/LibriSpeech/$part/27 $orglibrispeech/train/27
ln -sf $fullpath/LibriSpeech/$part/32 $orglibrispeech/train/32
ln -sf $fullpath/LibriSpeech/$part/39 $orglibrispeech/eval1/39

local/data_prep.sh $orglibrispeech/train data/train
local/data_prep.sh $orglibrispeech/eval1 data/eval1
cat data/eval1/text | local/wer_ref_filter >01_mono/test.ref

# download the LM resources
local/download_lm.sh $lm_url data/local/lm

wait

cp ./data/local/lm/librispeech-lexicon.txt ./librispeech
cp ./data/local/lm/librispeech-vocab.txt ./librispeech
local/librispeech_prepare_dict.sh

utils/prepare_lang.sh data/local/dict_nosp \
  "<UNK>" data/local/lang_tmp_nosp data/lang_nosp

local/format_lms.sh --src-dir data/lang_nosp data/local/lm

# Create ConstArpaLm format language model for full 3-gram and 4-gram LMs
utils/build_const_arpa_lm.sh data/local/lm/lm_tglarge.arpa.gz \
  data/lang_nosp data/lang_nosp_test_tglarge
utils/build_const_arpa_lm.sh data/local/lm/lm_fglarge.arpa.gz \
  data/lang_nosp data/lang_nosp_test_fglarge
