#!/bin/bash

. ./cmd.sh 
. ./path.sh

# DNNのsequential学習

config=conf/config_opt
. $config
gmmdir=../04_sat/exp/tri4
data_fmllr=../data-fmllr-tri4

. utils/parse_options.sh || exit 1;

# Sequence training using sMBR criterion, we do Stochastic-GD 
# with per-utterance updates. We use usually good acwt 0.1
# Lattices are re-generated after 1st epoch, to get faster convergence.
dir=exp/dnn5b_pretrain-dbn_dnn_smbr
srcdir=../08_dnn/exp/dnn5b_pretrain-dbn_dnn
acwt=0.0909

# ラティスの生成
# First we generate lattices and alignments:
steps/nnet/align.sh --nj 1 --cmd "$train_cmd" \
  $data_fmllr/train_nodup ../data/lang $srcdir dnn5b_pretrain-dbn_dnn_ali || exit 1;
# denlats
steps/nnet/make_denlats.sh --nj 1 --sub-split 1 --cmd "$decode_cmd" --config conf/decode_dnn.config \
  --acwt $acwt $data_fmllr/train_nodup ../data/lang $srcdir dnn5b_pretrain-dbn_dnn_denlats || exit 1;

# Re-train the DNN by 1 iteration of sMBR 
train_mpe.sh --cmd "$cuda_cmd" --num-iters 1 --acwt $acwt --do-smbr true --skip_cuda_check true \
  $data_fmllr/train_nodup ../data/lang $srcdir dnn5b_pretrain-dbn_dnn_ali dnn5b_pretrain-dbn_dnn_denlats $dir || exit 1

# Decode with the trigram csj language model.
skip_make_lattice=false # if true, skip making the lattice
for eval_num in `seq 1`; do
    mkdir -p $dir/decode_eval${eval_num}_csj
    if $skip_make_lattice ; then
        # 事前に作成したラティスを用いて認識率を計算する
        cp -r dnn5b_pretrain-dbn_dnn_smbr/lat.1.gz $dir/decode_eval${eval_num}_csj/lat.1.gz
        local/score.sh --min-lmwt 4 --max-lmwt 15 --cmd "run.pl" \
            $data_fmllr/eval${eval_num} $gmmdir/graph_csj_tg $dir/decode_eval${eval_num}_csj || exit 1;
    else
        # ラティスの作成から実行する
        steps/nnet/decode.sh --nj 1 --cmd "$decode_cmd" --config conf/decode_dnn.config --acwt 0.08333 \
	    --nnet $dir/1.nnet --acwt $acwt \
            $gmmdir/graph_csj_tg $data_fmllr/eval${eval_num} $dir/decode_eval${eval_num}_csj || exit 1;
    fi
done
