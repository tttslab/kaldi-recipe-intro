#!/bin/bash

. ./path.sh
. ./cmd.sh

dir=synoptmp/dnn5b_pretrain-dbn_demo
data=../data-fmllr-tri4/train_nodup

depth=2
num_hid=256

## フォワードパスの実行し正規化係数を求める
nnet-forward --use-gpu=no "nnet-concat $dir/tr_splice5-1_cmvn-g.nnet $dir/1.dbn - |" ark:"copy-feats scp:$dir/train.scp ark:- |" ark:- |\
compute-cmvn-stats ark:- - |\
cmvn-to-nnet - $dir/$depth.cmvn

## 中間層RBMの初期化
 echo "<NnetProto>
    <Rbm> <InputDim> $num_hid <OutputDim> $num_hid <VisibleType> bern <HiddenType> bern <ParamStddev> 0.1  <VisibleBiasCmvnFilename> $dir/$depth.cmvn
    </NnetProto>
    " > $dir/$depth.rbm.proto
nnet-initialize $dir/$depth.rbm.proto $dir/$depth.rbm.init

## CD法により学習
rbm-train-cd1-frmshuff --use-gpu=no --learn-rate=0.4 --l2-penalty=0.0002 --num-iters=1 --verbose=1 "--feature-transform=nnet-concat $dir/tr_splice5-1_cmvn-g.nnet $dir/$((depth-1)).dbn - |" $dir/$depth.rbm.init ark:"copy-feats scp:$dir/train.scp ark:- |" $dir/$depth.rbm

## RBMをDBNに変換し、結合する
rbm-convert-to-nnet --binary=true $dir/$depth.rbm - |\
nnet-concat $dir/$((depth-1)).dbn - $dir/$depth.dbn

## 設定した階層になるまで繰り返す
