#! /bin/bash -x

#do_DTrain=false # if true, enable discriminative training
do_DTrain=true # if true, enable discriminative training

time ./00_0prep_librispeech2kaldi.sh >& 00_0prep_librispeech2kaldi.log

time ./00_1make_mfcc_cmvn.sh >& 00_1make_mfcc_cmvn.log

cd 01_mono
time  ./01_run.sh >& 01_run.log
cd ..

cd 02_delta
time  ./01_run.sh >& 01_run.log
cd ..

cd 03_feats_trans
time  ./run.sh >& run.log
cd ..

cd 04_sat
time  ./run.sh >& run.log
cd ..

if $do_DTrain ;then
    cd 05_mmi
    time  ./run.sh >& run.log
    cd ..
    cd 06_fmmi
    time  ./run.sh >& run.log
    cd ..
fi

time ./07_prep_dnn.sh >& 07_prep_dnn.log

cd 08_dnn
time  ./01_run.sh >& 01_run.log
cd ..

if $do_DTrain ;then
    cd 09_dnn_s
    time  ./run.sh >& run.log
    cd ..
fi

# Get results.
#for x in *_*/exp/*/decode_eval1*_librispeech; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done;
