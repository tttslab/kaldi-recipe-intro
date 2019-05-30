#!/bin/bash

. ./cmd.sh
. ./path.sh
set -e # exit on error

# Begin feature trans
# From now, we start with the LDA+MLLT system

# LDA+MLLTを用いたtri-phone GMM-HMMの学習
time steps/train_lda_mllt.sh --cmd "$train_cmd" \
  600 5000 ../data/train_nodup ../data/lang_nosp ../02_delta/exp/tri2_ali_nodup exp/tri3

# 認識用WFSTの作成
graph_dir=exp/tri3/graph_librispeech_tg
$train_cmd $graph_dir/mkgraph.log \
    utils/mkgraph.sh ../data/lang_nosp_test_tgsmall exp/tri3 $graph_dir

for eval_num in `seq 1`; do
    # 認識
    time steps/decode_nolats.sh --nj 1 --cmd "$decode_cmd" --config conf/decode.config \
	$graph_dir ../data/eval${eval_num} exp/tri3/decode_eval${eval_num}_nosp_librispeech
    # 認識率の計算
    zcat exp/tri3/decode_eval${eval_num}_nosp_librispeech/words.*.gz | copy-int-vector ark:- ark,t:- >exp/tri3/decode_eval${eval_num}_nosp_librispeech/nolats_int.hyp
    int2sym.pl -f 2: ../data/lang_nosp_test_tgsmall/words.txt  exp/tri3/decode_eval${eval_num}_nosp_librispeech/nolats_int.hyp | local/wer_hyp_filter >exp/tri3/decode_eval${eval_num}_nosp_librispeech/nolats_stem.hyp
    compute-wer --mode=all --text ark:test.ref  ark:exp/tri3/decode_eval${eval_num}_nosp_librispeech/nolats_stem.hyp >exp/tri3/decode_eval${eval_num}_nosp_librispeech/wer_nolats
done


# 次ステップのためのアライメントの作成
time steps/align_fmllr.sh --nj 1 --cmd "$train_cmd" \
  ../data/train_nodup ../data/lang_nosp exp/tri3 exp/tri3_ali_nodup
