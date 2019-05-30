#!/bin/bash

. ./cmd.sh
. ./path.sh
set -e # exit on error

# mono phoneの学習
time steps/train_mono.sh --nj 1 --cmd "$train_cmd" \
  ../data/train_nodup ../data/lang_nosp exp/mono 

# 認識用WFSTの作成
graph_dir=exp/mono/graph_csj_tg
utils/mkgraph.sh --mono ../data/lang_nosp_csj_tg exp/mono $graph_dir

for eval_num in `seq 1`; do
    # 認識
    time steps/decode_nolats.sh --nj 1 --cmd "$decode_cmd" --config conf/decode.config \
        $graph_dir ../data/eval${eval_num} exp/mono/decode_eval${eval_num}_csj
    # 認識率の計算
    zcat exp/mono/decode_eval${eval_num}_csj/words.*.gz | copy-int-vector ark:- ark,t:- >exp/mono/decode_eval${eval_num}_csj/nolats_int.hyp
    int2sym.pl -f 2: ../data/lang_nosp_csj_tg/words.txt  exp/mono/decode_eval${eval_num}_csj/nolats_int.hyp | local/wer_hyp_filter >exp/mono/decode_eval${eval_num}_csj/nolats_stem.hyp
    compute-wer --mode=all --text ark:test.ref  ark:exp/mono/decode_eval${eval_num}_csj/nolats_stem.hyp >exp/mono/decode_eval${eval_num}_csj/wer_nolats
done

# 次ステップのためのアライメントの作成
time steps/align_si.sh --nj 1 --cmd "$train_cmd" \
  ../data/train_nodup ../data/lang_nosp exp/mono exp/mono_ali 
