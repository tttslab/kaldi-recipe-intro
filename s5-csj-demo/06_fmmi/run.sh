#!/bin/bash

. ./cmd.sh
. ./path.sh
set -e # exit on error

# fMMI+MMI 学習
time steps/train_diag_ubm.sh --silence-weight 0.5 --nj 1 --cmd "$train_cmd" \
  200 ../data/train_nodup ../data/lang ../04_sat/exp/tri4_ali_nodup exp/tri4_dubm

time steps/train_mmi_fmmi.sh --learning-rate 0.005 --boost 0.1 --cmd "$train_cmd" \
  ../data/train_nodup ../data/lang ../04_sat/exp/tri4_ali_nodup exp/tri4_dubm \
  ../04_sat/exp/tri4_denlats_nodup exp/tri4_fmmi_b0.1  

for eval_num in `seq 1`; do
    for iter in 4 5 6 7 8; do
	graph_dir=../04_sat/exp/tri4/graph_csj_tg
	decode_dir=exp/tri4_fmmi_b0.1/decode_eval${eval_num}_it${iter}_csj
	
	time steps/decode_nolats.sh --nj 1 --cmd "$decode_cmd" --iter $iter \
	    --transform-dir ../04_sat/exp/tri4/decode_eval${eval_num}_csj \
	    --config conf/decode.config $graph_dir ../data/eval${eval_num} $decode_dir

	zcat $decode_dir/words.*.gz | copy-int-vector ark:- ark,t:- >$decode_dir/nolats_int.hyp
	 int2sym.pl -f 2: ../data/lang_csj_tg/words.txt  $decode_dir/nolats_int.hyp | local/wer_hyp_filter >$decode_dir/nolats_stem.hyp
	 compute-wer --mode=all --text ark:test.ref  ark:$decode_dir/nolats_stem.hyp >$decode_dir/wer_nolats
    done
done
wait
echo "tri4 fmmi decode end : `date`"

