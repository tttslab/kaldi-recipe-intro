#!/bin/bash 

. cmd.sh
. path.sh
set -e # exit on error

#特徴量関係のコマンド例

mkdir -p synoptmp

#MFCC特徴量の抽出
compute-mfcc-feats --config=conf/mfcc.conf scp,p:data/train/wav.scp ark:synoptmp/mfcc

#CMVN統計量の計算
compute-cmvn-stats --spk2utt=ark:data/train/spk2utt ark:synoptmp/mfcc ark:synoptmp/cmvn

#テキストファイルに変換して中身を確認
#アーカイブ形式Wavデータのセグメント情報
wav-to-duration scp:data/train/wav.scp ark,t:synoptmp/dur.txt
#抽出した特徴量データの値
copy-feats ark:synoptmp/mfcc ark,t:synoptmp/feats.txt
#ケプストラム正規化定数
copy-feats ark:synoptmp/cmvn ark,t:synoptmp/cmvn.txt
