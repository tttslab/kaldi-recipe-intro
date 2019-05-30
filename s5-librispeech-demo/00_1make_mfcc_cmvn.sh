#!/bin/bash 

. ./cmd.sh
. ./path.sh
set -e # exit on error

# 評価セットと学習セットの特徴量を作成
mfccdir=mfcc

for x in train eval1; do
  steps/make_mfcc.sh --nj 1 --cmd "$train_cmd" \
    data/$x exp/make_mfcc/$x $mfccdir
  steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir
  utils/fix_data_dir.sh data/$x
done

echo "Finish creating MFCCs"

# Remove duplication utterances.
# (付加的な後処理として、過剰に出現する発話を削除)
utils/data/remove_dup_utts.sh 300 data/train data/train_nodup