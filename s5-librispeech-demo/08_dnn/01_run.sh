#!/bin/bash

. ./cmd.sh
. ./path.sh

# DNNの学習

config=config_opt_demo
. ./$config

gmmdir=../04_sat/exp/tri4
data_fmllr=../data-fmllr-tri4

. ./utils/parse_options.sh || exit 1;

# RBMを用いたプレトレーニング
echo "RBM pretrainig."
dir=exp/dnn5b_pretrain-dbn
$cuda_cmd $dir/log/pretrain_dbn.log \
    ./pretrain_dbn.sh --config $config --rbm-iter 1 --skip_cuda_check true \
    $data_fmllr/train_nodup $dir || exit 1;

# クロスエントロピーを用いたファインチューニング
echo "Fine tuning with cross entropy criteria."
dir=exp/dnn5b_pretrain-dbn_dnn
ali=${gmmdir}_ali_nodup
feature_transform=exp/dnn5b_pretrain-dbn/final.feature_transform
dbn=exp/dnn5b_pretrain-dbn/${nn_depth}.dbn
$cuda_cmd $dir/log/train_nnet.log \
    ./train.sh --config $config --feature-transform $feature_transform --dbn $dbn \
    --hid-layers 0 --learn-rate $learn_rate  --skip_cuda_check true --train_tool_opts --use-gpu=no\
    $data_fmllr/train_nodup_tr90 $data_fmllr/train_nodup_cv10 ../data/lang_nosp $ali $ali $dir || exit 1;

# Decode with the trigram librispeech language model.
skip_make_lattice=false # if true, skip making the lattice
for eval_num in `seq 1`; do
    mkdir -p $dir/decode_eval${eval_num}_librispeech
    if $skip_make_lattice ; then
	# 事前に作成したラティスを用いて認識率を計算する
	cp -r dnn5b_pretrain-dbn_dnn/lat.1.gz $dir/decode_eval${eval_num}_librispeech/lat.1.gz
	local/score.sh --min-lmwt 4 --max-lmwt 15 --cmd "run.pl" \
            $data_fmllr/eval${eval_num} $gmmdir/graph_librispeech_tg $dir/decode_eval${eval_num}_librispeech || exit 1;
    else
	# ラティスの作成から実行する
	steps/nnet/decode.sh --nj 1 --cmd "$decode_cmd" --config conf/decode_dnn.config --acwt 0.08333 \
            $gmmdir/graph_librispeech_tg $data_fmllr/eval${eval_num} $dir/decode_eval${eval_num}_librispeech || exit 1;
    fi
done
