#!/bin/bash

. ./cmd.sh
. ./path.sh

config=conf/config_opt
. $config
gmmdir=04_sat/exp/tri4
data_fmllr=data-fmllr-tri4

. utils/parse_options.sh || exit 1;

# fMLLRを予め適用したデータを作成してディスクに保存

# evaluation set
for eval_num in `seq 1`; do
    dir=$data_fmllr/eval${eval_num}
    steps/nnet/make_fmllr_feats.sh --nj 1 --cmd "$train_cmd" \
	--transform-dir $gmmdir/decode_eval${eval_num}_csj \
	$dir data/eval${eval_num} $gmmdir $dir/log $dir/data || exit 1
done
# train set
dir=$data_fmllr/train_nodup
steps/nnet/make_fmllr_feats.sh --nj 1 --cmd "$train_cmd" \
    --transform-dir ${gmmdir}_ali_nodup \
    $dir data/train_nodup $gmmdir $dir/log $dir/data || exit 1
# split the data : 90% train 10% cross-validation (held-out)
# デモ用軽量版スクリプトでは4話者中の１話者をheld-outとして用いる
utils/subset_data_dir_tr_cv.sh --cv-spk-percent 25 \
    $dir ${dir}_tr90 ${dir}_cv10 || exit 1

