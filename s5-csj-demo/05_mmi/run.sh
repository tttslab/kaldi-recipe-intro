#!/bin/bash

. ./cmd.sh
. ./path.sh
set -e # exit on error

### MMI 学習
# LDA+MLLT+SAT 特徴量を使用

num_mmi_iters=4
time steps/train_mmi.sh --cmd "$decode_cmd" --boost 0.1 --num-iters $num_mmi_iters \
  ../data/train_nodup ../data/lang ../04_sat/exp/tri4_ali_nodup ../04_sat/exp/tri4_denlats_nodup exp/tri4_mmi_b0.1 

for eval_num in `seq 1`; do
    for iter in 1 2 3 4; do
	graph_dir=../04_sat/exp/tri4/graph_csj_tg
	decode_dir=exp/tri4_mmi_b0.1/decode_eval${eval_num}_${iter}.mdl_csj

	time steps/decode_nolats.sh --nj 1 --cmd "$decode_cmd" --config conf/decode.config \
	    --iter $iter --transform-dir ../04_sat/exp/tri4/decode_eval${eval_num}_csj \
	    $graph_dir ../data/eval${eval_num} $decode_dir   
	
	 zcat exp/tri4_mmi_b0.1/decode_eval${eval_num}_${iter}.mdl_csj/words.*.gz | copy-int-vector ark:- ark,t:- >exp/tri4_mmi_b0.1/decode_eval${eval_num}_${iter}.mdl_csj/nolats_int.hyp
	 int2sym.pl -f 2: ../data/lang_csj_tg/words.txt  exp/tri4_mmi_b0.1/decode_eval${eval_num}_${iter}.mdl_csj/nolats_int.hyp | local/wer_hyp_filter >exp/tri4_mmi_b0.1/decode_eval${eval_num}_${iter}.mdl_csj/nolats_stem.hyp
	 compute-wer --mode=all --text ark:test.ref  ark:exp/tri4_mmi_b0.1/decode_eval${eval_num}_${iter}.mdl_csj/nolats_stem.hyp >exp/tri4_mmi_b0.1/decode_eval${eval_num}_${iter}.mdl_csj/wer_nolats
    done
done
wait
echo "tri4 mmi decode end : `date`"
