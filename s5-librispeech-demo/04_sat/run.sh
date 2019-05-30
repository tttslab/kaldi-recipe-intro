#!/bin/bash

. ./cmd.sh
. ./path.sh
set -e # exit on error

# 話者適応学習
# ここで作成した変換行列は、この後の識別学習やNNでも使用。

# 学習セット用のFMLLR変換行列の作成。
# Train tri4, which is LDA+MLLT+SAT, on all the (nodup) data.
time steps/train_sat.sh  --cmd "$train_cmd" \
  600 5000 ../data/train_nodup ../data/lang_nosp ../03_feats_trans/exp/tri3_ali_nodup exp/tri4

# 認識用WFSTの作成
graph_dir=exp/tri4/graph_librispeech_tg
$train_cmd $graph_dir/mkgraph.log \
    utils/mkgraph.sh ../data/lang_nosp_test_tgsmall exp/tri4 $graph_dir

for eval_num in `seq 1`; do
    # 認識処理(ラティスを作成)と、評価セット用のFMLLR変換行列の作成。
    # 認識率の計算はスクリプトの中で行なっている。
    time steps/decode_fmllr.sh --nj 1 --cmd "$decode_cmd" --config conf/decode.config \
	$graph_dir ../data/eval${eval_num} exp/tri4/decode_eval${eval_num}_librispeech
done

# 次ステップのためのアライメントの作成
echo "tri4 ali begin : `date`"
steps/align_fmllr.sh --nj 1 --cmd "$train_cmd" \
  ../data/train_nodup ../data/lang_nosp exp/tri4 exp/tri4_ali_nodup || exit 1
echo "tri4 ali end : `date`"

# NNの学習はここまでの結果を使用。
# 次の識別学習ステップは省略可(NNの学習には使用していない)。

# 識別学習を行なう場合は、ラティスを作成する
echo "tri4 denlats begin : `date`"
steps/make_denlats.sh --nj 1 --cmd "$decode_cmd" --config conf/decode.config \
  --transform-dir exp/tri4_ali_nodup \
  ../data/train_nodup ../data/lang_nosp exp/tri4 exp/tri4_denlats_nodup
echo "tri4 denlats end : `date`"
