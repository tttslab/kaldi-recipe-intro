#!/bin/bash

. ./path.sh

mkdir -p synoptmp

## steps/train_deltas.sh の概略
## トライフォンモデルの初期化

## cmvnを適応し、動的特徴量を付加する
apply-cmvn  --utt2spk=ark:../data/train_nodup/utt2spk scp:../data/train_nodup/cmvn.scp scp:../data/train_nodup/feats.scp ark:- | \
    add-deltas  ark:- ark:synoptmp/feats_norm

## モノフォンをもとにトライフォン統計量を蓄積する
acc-tree-stats --ci-phones=1:2:3:4:5:6:7:8:9:10 ../01_mono/exp/mono_ali/final.mdl ark:synoptmp/feats_norm \
    "ark:gunzip -c ../01_mono/exp/mono_ali/ali.1.gz|" synoptmp/treeacc

## 音素クラスタリングを行う
cluster-phones synoptmp/treeacc ../data/lang_nosp/phones/sets.int synoptmp/questions.int 

# 音素および無音の単語内位置情報に関する質問を加える(see extra_questions.txt)
cat ../data/lang_nosp/phones/extra_questions.int >> synoptmp/questions.int

# 決定木作成のための質問リストをコンパイルする
compile-questions ../data/lang_nosp/topo synoptmp/questions.int synoptmp/questions.qst

## 決定木作成
build-tree --verbose=1 --max-leaves=600 --cluster-thresh=-1 synoptmp/treeacc ../data/lang_nosp/phones/roots.int \
    synoptmp/questions.qst ../data/lang_nosp/topo synoptmp/tree

## 状態共有トライフォン初期モデルを作成
gmm-init-model --write-occs=synoptmp/1.occs synoptmp/tree synoptmp/treeacc ../data/lang_nosp/topo synoptmp/1.mdl

# ガウス混合数を増やす
gmm-mixup --mix-up=600 synoptmp/1.mdl synoptmp/1.occs synoptmp/1.mdl

## モノフォンのアライメントを状態共有トライフォンに対応したアライメントに変換する
convert-ali ../01_mono/exp/mono_ali/final.mdl synoptmp/1.mdl synoptmp/tree "ark:gunzip -c ../01_mono/exp/mono_ali/ali.1.gz|" ark:synoptmp/ali.1

## 発話ごとのFSTファイルの作成を行う
./utils/sym2int.pl --map-oov 2 -f 2- ../data/lang_nosp/words.txt < ../data/train_nodup/text >synoptmp/text.int
compile-train-graphs synoptmp/tree synoptmp/1.mdl ../data/lang_nosp/L.fst ark:synoptmp/text.int ark:synoptmp/fsts

## FSTファイルの中身を確認したい場合
#compile-train-graphs synoptmp/tree synoptmp/1.mdl ../data/lang_nosp/L.fst ark:synoptmp/text.int ark,t:synoptmp/fsts.txt


# 無音の確率を考慮して音響を修正
gmm-boost-silence --boost=1.0 1 synoptmp/1.mdl synoptmp/1.mdl_bsil 

## 強制アライメントをとる
gmm-align-compiled --transition-scale=1.0 --acoustic-scale=0.1 --self-loop-scale=0.1 --beam=6 --retry-beam=24 --careful=false \
    synoptmp/1.mdl_bsil ark:synoptmp/fsts ark:synoptmp/feats_norm ark,t:synoptmp/ali.1

## 統計量を蓄積する
gmm-acc-stats-ali synoptmp/1.mdl ark:synoptmp/feats_norm ark:synoptmp/ali.1 synoptmp/1.acc

## モデルを更新する
gmm-est --write-occs=synoptmp/2.occs --mix-up=776 --power=0.25 synoptmp/1.mdl synoptmp/1.acc synoptmp/2.mdl
