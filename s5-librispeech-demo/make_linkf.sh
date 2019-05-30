#!/bin/bash

# This script performs some preparation works for librispeech demo.
# Please put s5_demo directory that include this script under egs/librispeech/

[ ! -e ../../../egs ] && echo "Error: Please put s5_demo directory under egs/librispeech/." && exit 1;

echo "Modify some scripts and make link files for librispeech demo..."
ln -s ../../wsj/s5/steps steps 2>/dev/null
ln -s ../../wsj/s5/utils utils 2>/dev/null
ln -s ../../csj/s5/conf conf 2>/dev/null
cd local
ln -s ../steps/score_kaldi.sh score.sh 2>/dev/null
cd ..

[ ! -e steps ] && echo "Not found steps link file." && exit 1;
[ ! -e utils ] && echo "Not found utils link file." && exit 1;
[ ! -e conf ] && echo "Not found conf link file." && exit 1;
[ ! -e local/score.sh ] && echo "Not found local/score.sh link file." && exit 1;
if [ -e steps ] ;then
    echo -e "#!/bin/bash\n# 2019 librispeech Kaldi light version (by TokyoTech): GPU is turned off." > 08_dnn/train.sh
    sed 's:\-\-use\-gpu\=yes:\-\-use\-gpu\=no:g' steps/nnet/train.sh | grep -v "#!/bin/bash" >>08_dnn/train.sh || exit 1;
    echo -e "#!/bin/bash\n# 2019 librispeech Kaldi light version (by TokyoTech): GPU is turned off." > 08_dnn/pretrain_dbn.sh
    sed 's:\-\-use\-gpu\=yes:\-\-use\-gpu\=no:g' steps/nnet/pretrain_dbn.sh | grep -v "#!/bin/bash" | \
	sed 's:rbm-train-cd1-frmshuff:rbm-train-cd1-frmshuff \-\-use\-gpu\=no:g' >> 08_dnn/pretrain_dbn.sh || exit 1;
    sed "s:print(text, end=' '):exec(\'print(\\\'\' + str(text) + \'\\\', end=\\\' \\\')\'):g" utils/nnet/gen_splice.py | \
	sed "s:print text,:exec(\'print \\\'\' + str(text) + \'\\\',\'):g" > 08_dnn/gen_splice.py || exit 1;

    echo -e "#!/bin/bash\n# 2019 librispeech Kaldi light version (by TokyoTech): GPU is turned off." > 09_dnn_s/train_mpe.sh
    sed 's:nnet-train-mpe-sequential:nnet-train-mpe-sequential \-\-use\-gpu\=no:g' steps/nnet/train_mpe.sh >> 09_dnn_s/train_mpe.sh || exit 1;

    nolats=local/decode_dnn_nolats.sh
    echo -e "#!/bin/bash\n# 2019 librispeech Kaldi light version (by TokyoTech): Do not generate lattices." > $nolats
    sed 's:latgen\-faster\-mapped$thread\_string:decode\-faster\-mapped:g' steps/nnet/decode.sh |\
    sed 's:\-\-max\-mem\=\$max\_mem ::g' | sed 's:\-\-lattice\-beam\=\$lattice_beam ::g' |\
    sed 's:lat\.JOB\.gz\":words\.JOB\.gz\" \"ark\:\/dev\/null\":g' | grep -v "#!/bin/bash" >>$nolats || exit 1;
    chmod a+x $nolats 08_dnn/*.sh 08_dnn/gen_splice.py 09_dnn_s/train_mpe.sh
else
    echo "Error: Not found steps link file. " && exit 1;
fi

echo "Done!"
