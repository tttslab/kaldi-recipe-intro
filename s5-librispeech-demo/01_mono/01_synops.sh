#!/bin/bash

. ./path.sh
. ./cmd.sh

mkdir synoptmp

## steps/train_mono.sh の概略
## モノフォンモデルの初期化

## cmvnを適応し、動的特徴量を付加する
apply-cmvn  --utt2spk=ark:../data/train_nodup/utt2spk scp:../data/train_nodup/cmvn.scp scp:../data/train_nodup/feats.scp ark:- | add-deltas ark:- ark:synoptmp/feats_norm

## 特徴量ファイルを試しにいくつかテキスト形式で生成したい場合
#apply-cmvn  --utt2spk=ark:../data/train_nodup/utt2spk scp:../data/train_nodup/cmvn.scp scp:../data/train_nodup/feats.scp ark:- | add-deltas ark:- ark:- | \
# subset-feats --n=10 ark:- ark,t:synoptmp/feats_norm.txt

## モノフォン初期モデルの作成
gmm-init-mono --shared-phones=../data/lang_nosp/phones/sets.int --train-feats=ark:synoptmp/feats_norm ../data/lang_nosp/topo 39 synoptmp/0.mdl synoptmp/tree

## 発話ごとのFSTファイルの作成
./utils/sym2int.pl --map-oov 2 -f 2- ../data/lang_nosp/words.txt < ../data/train_nodup/text >synoptmp/text.int
compile-train-graphs synoptmp/tree synoptmp/0.mdl ../data/lang_nosp/L.fst ark:synoptmp/text.int ark:synoptmp/fsts
## FSTの中身を確認したい場合
#compile-train-graphs synoptmp/tree synoptmp/0.mdl ../data/lang_nosp/L.fst ark:synoptmp/text.int ark,t:synoptmp/fsts.txt

## 初期アライメントファイルの作成
align-equal-compiled ark:synoptmp/fsts ark:synoptmp/feats_norm ark,t:synoptmp/align_equal_compiled

## 統計量の蓄積
gmm-acc-stats-ali synoptmp/0.mdl ark:synoptmp/feats_norm ark:synoptmp/align_equal_compiled synoptmp/0.acc

## 統計量ファイルをテキスト形式で生成したい場合
#gmm-acc-stats-ali --binary=false synoptmp/0.mdl ark:synoptmp/feats_norm ark:synoptmp/align_equal_compiled synoptmp/0.acc.txt

## 音響尤度の最大化を行う
gmm-est --min-gaussian-occupancy=3 --mix-up=136 --power=0.25 synoptmp/0.mdl synoptmp/0.acc synoptmp/1.mdl



## 無音の確率を考慮して音響モデルを修正
gmm-boost-silence --boost=1.0 1 synoptmp/1.mdl synoptmp/1.mdl_bsil 

## 強制アライメントをとる
gmm-align-compiled --transition-scale=1.0 --acoustic-scale=0.1 --self-loop-scale=0.1 --beam=6 --retry-beam=24 \
    --careful=false synoptmp/1.mdl_bsil ark:synoptmp/fsts ark:synoptmp/feats_norm ark,t:synoptmp/ali.1

## 統計量を蓄積する
gmm-acc-stats-ali synoptmp/1.mdl ark:synoptmp/feats_norm ark:synoptmp/ali.1 synoptmp/1.acc

## モデルを更新する
gmm-est --write-occs=synoptmp/2.occs --mix-up=136 --power=0.25 synoptmp/1.mdl synoptmp/1.acc synoptmp/2.mdl
