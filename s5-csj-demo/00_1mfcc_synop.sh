#!/bin/bash 

. cmd.sh
. path.sh
set -e # exit on error

#特徴量関係のコマンド例

mkdir -p synoptmp

#セグメントごとのWavデータをアーカイブ形式で保存
extract-segments scp,p:data/train/wav.scp data/train/segments ark,scp:synoptmp/extract_segment.ark,synoptmp/extract_segment.scp

#MFCC特徴量の抽出
compute-mfcc-feats --config=conf/mfcc.conf ark:synoptmp/extract_segment.ark ark:synoptmp/mfcc

#CMVN統計量の計算
compute-cmvn-stats --spk2utt=ark:data/train/spk2utt ark:synoptmp/mfcc ark:synoptmp/cmvn

#テキストファイルに変換して中身を確認
#アーカイブ形式Wavデータのセグメント情報
wav-to-duration scp:synoptmp/extract_segment.scp ark,t:synoptmp/dur.txt
#抽出した特徴量データの値
copy-feats ark:synoptmp/mfcc ark,t:synoptmp/feats.txt
#ケプストラム正規化定数
copy-feats ark:synoptmp/cmvn ark,t:synoptmp/cmvn.txt

