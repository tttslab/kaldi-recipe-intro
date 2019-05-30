#!/bin/bash

. ./path.sh
. ./cmd.sh

mkdir -p synoptmp
mkdir -p synoptmp/dnn5b_pretrain-dbn_demo

dir=synoptmp/dnn5b_pretrain-dbn_demo
data=../data-fmllr-tri4/train_nodup

## steps/nnet/pretrain_dbn.sh の概略
## RBMの学習を行う

# 特徴量のリストをシャッフルする
cat $data/feats.scp | utils/shuffle_list.pl --srand ${seed:-777} > $dir/train.scp

# パラメタを元に入力層の情報を抽出
./gen_splice.py --fea-dim=40 --splice=5 --splice-step=1 > $dir/tr_splice5-1.nnet

## Splice,CMVNの適用（NNの一つの層とみなす）
nnet-forward --use-gpu=no $dir/tr_splice5-1.nnet ark:"copy-feats scp:$dir/train.scp ark:- |" ark:- | compute-cmvn-stats ark:- - |\
cmvn-to-nnet - - | nnet-concat --binary=false $dir/tr_splice5-1.nnet - $dir/tr_splice5-1_cmvn-g.nnet


cp $dir/tr_splice5-1_cmvn-g.nnet $dir/final.feature_transform


num_fea=$(feat-to-dim --print-args=false "ark:copy-feats scp:$dir/train.scp ark:- | nnet-forward --use-gpu=no $dir/final.feature_transform ark:- ark:- |" - 2>/dev/null)
num_hid=256

## RBMの初期化
echo "<NnetProto>
    <Rbm> <InputDim> $num_fea <OutputDim> $num_hid <VisibleType> gauss <HiddenType> bern <ParamStddev> 0.1
    </NnetProto>
    " > $dir/1.rbm.proto
nnet-initialize $dir/1.rbm.proto $dir/1.rbm.init

## CD法により学習
rbm-train-cd1-frmshuff --use-gpu=no --learn-rate=0.01 --l2-penalty=0.0002 --num-iters=2 --verbose=1 \
    --feature-transform=$dir/tr_splice5-1_cmvn-g.nnet $dir/1.rbm.init ark:"copy-feats scp:$dir/train.scp ark:- |" $dir/1.rbm 

## 学習したRBMをDBNに変換
rbm-convert-to-nnet --binary=true $dir/1.rbm $dir/1.dbn

