#!/bin/bash

. ./cmd.sh
. ./path.sh
set -e # exit on error

# deltaとdelta-delta特徴量を用いたtri-phone GMM-HMMの学習
time steps/train_deltas.sh --cmd "$train_cmd" \
  600 5000 ../data/train_nodup ../data/lang_nosp ../01_mono/exp/mono_ali exp/tri1

# 認識用WFSTの作成
graph_dir=exp/tri1/graph_librispeech_tg
$train_cmd $graph_dir/mkgraph.log \
    utils/mkgraph.sh ../data/lang_nosp_test_tgsmall exp/tri1 $graph_dir

for eval_num in `seq 1`; do
    # 認識
    time steps/decode_nolats.sh --nj 1 --cmd "$decode_cmd" --config conf/decode.config \
	$graph_dir ../data/eval${eval_num} exp/tri1/decode_eval${eval_num}_librispeech
    # 認識率の計算
    zcat exp/tri1/decode_eval${eval_num}_librispeech/words.*.gz | copy-int-vector ark:- ark,t:- >exp/tri1/decode_eval${eval_num}_librispeech/nolats_int.hyp
    int2sym.pl -f 2: ../data/lang_nosp_test_tgsmall/words.txt  exp/tri1/decode_eval${eval_num}_librispeech/nolats_int.hyp | local/wer_hyp_filter >exp/tri1/decode_eval${eval_num}_librispeech/nolats_stem.hyp
    compute-wer --mode=all --text ark:test.ref  ark:exp/tri1/decode_eval${eval_num}_librispeech/nolats_stem.hyp >exp/tri1/decode_eval${eval_num}_librispeech/wer_nolats
done

# 次ステップのためのアライメントの作成
time steps/align_si.sh --nj 1 --cmd "$train_cmd" \
  ../data/train_nodup ../data/lang_nosp exp/tri1 exp/tri2_ali_nodup
