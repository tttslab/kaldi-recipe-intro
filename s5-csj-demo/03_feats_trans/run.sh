#!/bin/bash

. ./cmd.sh
. ./path.sh
set -e # exit on error

# Begin feature trans     
# From now, we start with the LDA+MLLT system


## CSJレシピでは、ここから全学習データを使用（ここまではサブセットを使用）

# LDA+MLLTを用いたtri-phone GMM-HMMの学習
time steps/train_lda_mllt.sh --cmd "$train_cmd" \
  600 5000 ../data/train_nodup ../data/lang_nosp ../02_delta/exp/tri2_ali_nodup exp/tri3

# 認識用WFSTの作成
graph_dir=exp/tri3/graph_csj_tg
$train_cmd $graph_dir/mkgraph.log \
    utils/mkgraph.sh ../data/lang_nosp_csj_tg exp/tri3 $graph_dir

for eval_num in `seq 1`; do
    # 認識
    time steps/decode_nolats.sh --nj 1 --cmd "$decode_cmd" --config conf/decode.config \
	$graph_dir ../data/eval${eval_num} exp/tri3/decode_eval${eval_num}_nosp_csj
    # 認識率の計算
    zcat exp/tri3/decode_eval${eval_num}_nosp_csj/words.*.gz | copy-int-vector ark:- ark,t:- >exp/tri3/decode_eval${eval_num}_nosp_csj/nolats_int.hyp
    int2sym.pl -f 2: ../data/lang_nosp_csj_tg/words.txt  exp/tri3/decode_eval${eval_num}_nosp_csj/nolats_int.hyp | local/wer_hyp_filter >exp/tri3/decode_eval${eval_num}_nosp_csj/nolats_stem.hyp
    compute-wer --mode=all --text ark:test.ref  ark:exp/tri3/decode_eval${eval_num}_nosp_csj/nolats_stem.hyp >exp/tri3/decode_eval${eval_num}_nosp_csj/wer_nolats
done

#############################################################################################
# 言語モデルの再作成

# Now we compute the pronunciation and silence probabilities from training data,
# and re-create the lang directory.
steps/get_prons.sh --cmd "$train_cmd" ../data/train_nodup ../data/lang_nosp exp/tri3
utils/dict_dir_add_pronprobs.sh --max-normalize true \
  ../data/local/dict_nosp exp/tri3/pron_counts_nowb.txt exp/tri3/sil_counts_nowb.txt \
  exp/tri3/pron_bigram_counts_nowb.txt ../data/local/dict

cd ..
utils/prepare_lang.sh data/local/dict "<unk>" data/local/lang data/lang
LM=data/local/lm/csj.o3g.kn.gz
srilm_opts="-subset -prune-lowprobs -unk -tolower -order 3"
utils/format_lm_sri.sh --srilm-opts "$srilm_opts" \
  data/lang $LM data/local/dict/lexicon.txt data/lang_csj_tg
cd 03_feats_trans

graph_dir=exp/tri3/graph_csj_tg
$train_cmd $graph_dir/mkgraph.log \
    utils/mkgraph.sh ../data/lang_csj_tg exp/tri3 $graph_dir

for eval_num in `seq 1`; do
    time steps/decode_nolats.sh --nj 1 --cmd "$decode_cmd" --config conf/decode.config \
        $graph_dir ../data/eval${eval_num} exp/tri3/decode_eval${eval_num}_csj
    zcat exp/tri3/decode_eval${eval_num}_csj/words.*.gz | copy-int-vector ark:- ark,t:- >exp/tri3/decode_eval${eval_num}_csj/nolats_int.hyp
    int2sym.pl -f 2: ../data/lang_csj_tg/words.txt  exp/tri3/decode_eval${eval_num}_csj/nolats_int.hyp | local/wer_hyp_filter >exp/tri3/decode_eval${eval_num}_csj/nolats_stem.hyp
    compute-wer --mode=all --text ark:test.ref  ark:exp/tri3/decode_eval${eval_num}_csj/nolats_stem.hyp >exp/tri3/decode_eval${eval_num}_csj/wer_nolats
done

#############################################################################################
# 次ステップのためのアライメントの作成
time steps/align_fmllr.sh --nj 1 --cmd "$train_cmd" \
  ../data/train_nodup ../data/lang exp/tri3 exp/tri3_ali_nodup 

