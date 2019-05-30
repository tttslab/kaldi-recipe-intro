#!/bin/bash

. ./cmd.sh
. ./path.sh
set -e # exit on error

## 使用するデータ下記の通りです．
## 短単位長単位混合形式形態論データ :  SDB/core/*.sdb
## 学会講演の音声データ : A01F0055.wav A01F0067.wav A01M0097.wav A01F0122.wav A01F0132.wav

## 上記で指定のデータを"./CSJ"ディレクトリの下に置いてください．
orgcsj=CSJ
mkdir -p $orgcsj
#[ 0 -eq `ls $orgcsj | wc -l` ] && echo "ERROR $0 : Directory $orgcsj is empty." && exit 1;
if [ 0 -eq `ls $orgcsj | wc -l` ]; then
    echo "ERROR $0 : Directory $orgcsj is empty."
    echo "You need to copy SDB/core/*.sdb, A01F0055.wav, A01F0067.wav, A01M0097.wav, A01F0122.wav and A01F0132.wav to ${orgcsj} directory."
    exit 1;
fi

# データの下準備
if [ ! -d data/csj-data/.done_make_all ]; then
 local/csj_make_trans/csj_autorun4demo.sh $orgcsj data/csj-data
fi
wait

# 発話リストの作成など
local/csj_data_prep.sh data/csj-data

# 辞書および言語モデルの作成
local/csj_prepare_dict.sh 
utils/prepare_lang.sh data/local/dict_nosp "<unk>" data/local/lang_nosp data/lang_nosp
local/csj_train_lms.sh data/local/train/text data/local/dict_nosp/lexicon.txt data/local/lm
srilm_opts="-subset -prune-lowprobs -unk -tolower -order 3"
LM=data/local/lm/csj.o3g.kn.gz
utils/format_lm_sri.sh --srilm-opts "$srilm_opts" \
  data/lang_nosp $LM data/local/dict_nosp/lexicon.txt data/lang_nosp_csj_tg

# 評価セットの準備
for eval_dev in eval1 ; do
    local/csj_eval_data_prep.sh data/csj-data/eval $eval_dev
    cat data/$eval_dev/text | local/wer_ref_filter >01_mono/test.ref
done
