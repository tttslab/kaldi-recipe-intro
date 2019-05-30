#!/bin/bash

. ./path.sh
. ./cmd.sh

mkdir -p synoptmp/dnn5b_pretrain-dbn_dnn_demo
mkdir -p synoptmp/dnn5b_pretrain-dbn_dnn_demo/nnet

## steps/nnet/train.sh , steps/nnet/train_scheduler.sh の概略
## DNNの学習を行う

dir=synoptmp/dnn5b_pretrain-dbn_dnn_demo
data=../data-fmllr-tri4
gmm_ali=../04_sat/exp/tri4_ali_nodup

depth=2
iter=01
feature_transform=synoptmp/dnn5b_pretrain-dbn_demo/final.feature_transform
dbn=synoptmp/dnn5b_pretrain-dbn_demo/$depth.dbn

# get pdf-counts, used later to post-process DNN posteriors
## アライメントをPDF-IDに変換
ali-to-pdf $gmm_ali/final.mdl "ark:gunzip -c $gmm_ali/ali.*.gz |" ark:$dir/pdf_ali
# ダンプ
ali-to-pdf $gmm_ali/final.mdl "ark:gunzip -c $gmm_ali/ali.*.gz |" ark,t:$dir/pdf_ali.txt
## 各PDFの出現回数をカウント
analyze-counts --verbose=1 --binary=false ark:$dir/pdf_ali $dir/ali_train_pdf.counts

# バイナリ形式のモデルをint形式に変換
copy-transition-model --binary=false $gmm_ali/final.mdl $dir/final.mdl

cp $gmm_ali/tree $dir/tree 

# make phone counts for analysis
# アライメントを各音素に変換
ali-to-phones --per-frame=true $gmm_ali/final.mdl "ark:gunzip -c $gmm_ali/ali.*.gz |" ark:$dir/phones_ali
# ダンプ
ali-to-phones --per-frame=true $gmm_ali/final.mdl "ark:gunzip -c $gmm_ali/ali.*.gz |" ark,t:$dir/phones_ali.txt
# 各音素の出現頻度をカウント
analyze-counts --verbose=1 --symbol-table=../data/lang/phones.txt ark:$dir/phones_ali $dir/ali_train_phones.counts

cat $data/train_nodup_tr90/feats.scp | utils/shuffle_list.pl --srand ${seed:-777} > $dir/train.scp

feats_tr="ark:copy-feats scp:$dir/train.scp ark:- |"
cp $data/train_nodup_cv10/feats.scp $dir/cv.scp
feats_cv="ark:copy-feats scp:$dir/cv.scp ark:- |"
num_fea= num_fea=$(nnet-forward "nnet-concat $feature_transform $dbn -|" "$feats_tr" ark:- | feat-to-dim ark:- -)
num_tgt=$(hmm-info --print-args=false $gmm_ali/final.mdl | grep pdfs | awk '{ print $NF }')

## 出力層の作成
utils/nnet/make_nnet_proto.py $num_fea $num_tgt 0 1 >$dir/nnet.proto
nnet-initialize $dir/nnet.proto $dir/nnet.init

## DNNの作成
nnet-concat $dbn $dir/nnet.init $dir/nnet_$depth.dbn_dnn.init

cp $feature_transform $dir

## アライメントの情報を用いてDNN事後確率（出力層）に変換
ali-to-post ark:$dir/pdf_ali ark:$dir/pdf_post

## ミニバッチを用いた学習（学習セット）
nnet-train-frmshuff --use-gpu=no --learn-rate=0.008 --momentum=1.0e-05 --l1-penalty=0 --l2-penalty=0 --minibatch-size=256 --randomizer-size=32768 --randomize=true --verbose=1 --binary=true --feature-transform=$feature_transform --randomizer-seed=777 "ark:copy-feats scp:$dir/train.scp ark:- |" ark:$dir/pdf_post $dir/nnet_$depth.dbn_dnn.init $dir/nnet/nnet_$depth.dbn_dnn_iter$iter

## ミニバッチを用いた学習（クロスバリデーションセット）
nnet-train-frmshuff --use-gpu=no --cross-validate=true --minibatch-size=256 --randomizer-size=32768 --randomize=false --verbose=1 --feature-transform=$dir/final.feature_transform "ark:copy-feats scp:$dir/cv.scp ark:- |" ark:$dir/pdf_post $dir/nnet/nnet_$depth.dbn_dnn_iter$iter

## クロスバリデーションセットの前のエポックと現在のクロスエントロピーの値の相対改善率が
## 既定値を下回る場合（デフォルト値 0.01）、学習率を半分にする
## クロスバリデーションセットの相対改善率が既定値（デフォルト値 0.001）を下回ったら学習終了
