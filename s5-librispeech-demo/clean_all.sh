#!/bin/bash

# 演習リセット用スクリプト
# demoスクリプトで生成されるファイルやディレクトリを全て削除

# リセット用スクリプト
# demoスクリプトで生成されるファイルやディレクトリを全て削除

# 実験データ・結果の削除
rm -rf data data-fmllr-tri4 synoptmp mfcc exp synoptmp 01_mono/test.ref *_*/{exp,synoptmp} 09_dnn_s/dnn5b_pretrain-dbn_dnn_{ali,denlats}

# リンクファイル・demo用に自動生成したスクリプトの削除
rm steps utils conf local/score.sh 08_dnn/{pretrain_dbn.sh,train.sh,gen_splice.py} local/decode_dnn_nolats.sh 09_dnn_s/train_mpe.sh

# ログファイルの削除
rm -f *_*/*.log *.log
