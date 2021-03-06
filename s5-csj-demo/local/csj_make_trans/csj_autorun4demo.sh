#! /bin/bash

# Copyright  2015 Tokyo Institute of Technology (Authors: Takafumi Moriya and Takahiro Shinozaki)
#            2015 Mitsubishi Electric Research Laboratories (Author: Shinji Watanabe)
# Apache 2.0
# Acknowledgement  This work was supported by JSPS KAKENHI Grant Number 26280055.

# Modified for CSJ demo.

if [ $# -ne 2 ]; then
  echo "Usage: "`basename $0`" <speech-dir> <transcription-dir>"
  echo "e.g., "`basename $0`" /database/NINJAL/CSJ data/csj-data"
  echo "See comments in the script for more details"
  exit 1
fi

resource=$1
outd=$2

[ ! -e $resource ] && echo "Not exist CSJ or incorrect PATH." && exit 1;

if [ ! -e $outd/.done_make_trans ];then
(
    echo "Make Transcription and PATH of WAV file."
    mkdir -p $outd
    rm -f $outd/README.txt
    echo "Contents about generated directory and file
          ## About each directory
          {dvd3(dvd) or core(usb)}                         :Contain training data
          eval/                                            :Official evaluation data set ( *** Extract from dvd *** )
          excluded/                                        :Same speaker data including evaluation data (e.g. A01M0056) ( *** Extract from dvd *** )

          ## About each file
          {dvd3(dvd) or core(usb)}/A01F0055
                                   A01F0055-trans.text     :Transcriptions (utterances with R-tags are removed)
                                   A01F0055-wav.list       :Path about existing wav file
                                   A01F0055.4lex           :File for making lexicon" >$outd/README.txt

    # Make transcription file for each dvd and each lecture
    [ ! -x "`which nkf `" ]\
        && echo "This processing is need to prepare \"nkf\" command. Please retry after installing command \"nkf\"." && exit 1;

    mkdir -p $outd
    (
	#if [ $csjv = "merl" ]; then
	#    ids=`ls $resource/$vol/$SDB | sed 's:.sdb::g' | sed 's/00README.txt//g'`
	#else
	#    ids=`ls $resource/${SDB}$vol | sed 's:.sdb::g' | sed 's/00README.txt//g'`
	#fi
	ids=`ls $resource | grep sdb | sed 's:\.sdb::g' | sort -u`
	
	for id in $ids; do
	    mkdir -p $outd/core/$id
	    #case "$csjv" in
		#"usb" ) TPATH="$resource/${SDB}$vol" ; WPATH="$resource/$WAV" ;;
		#"dvd" ) TPATH="$resource/$vol/$id"   ; WPATH="$resource/$vol/$id" ;;
		#"merl" ) TPATH="$resource/$vol/$SDB" ; WPATH="$resource/$vol/$WAV" ;;
	    #esac
	    #local/csj_make_trans/csj2kaldi4m.pl $TPATH/${id}.sdb  $outd/$vol/$id/${id}.4lex $outd/$vol/$id/${id}.4trn.t || exit 1;
	    #local/csj_make_trans/csjconnect.pl 0.5 10 $outd/$vol/$id/${id}.4trn.t $id > $outd/$vol/$id/${id}-trans.text || exit 1;
	    #rm $outd/$vol/$id/${id}.4trn.t
       	    #if [ -e $WPATH/${id}-L.wav ]; then
		#find $WPATH -iname "${id}-[L,R].wav" >$outd/$vol/$id/${id}-wav.list
	    #else
		#find $WPATH -iname ${id}.wav >$outd/$vol/$id/${id}-wav.list || exit 1;
	    #fi
	    
            nkf -e -d $resource/${id}.sdb > $outd/core/${id}/sdb.tmp
            local/csj_make_trans/csj2kaldi4m.pl $outd/core/${id}/sdb.tmp  $outd/core/$id/${id}.4lex $outd/core/$id/${id}.4trn.t 
            local/csj_make_trans/csjconnect.pl 0.5 10 $outd/core/$id/${id}.4trn.t $id > $outd/core/$id/${id}-trans.text
            
            rm $outd/core/$id/{${id}.4trn.t,sdb.tmp}
            
            [ -e $resource/${id}.wav ]\
           && find $resource -iname "${id}.wav" >$outd/core/$id/${id}-wav.list
	done
    )&
    wait

    if [ -s $outd/core/$id/${id}-trans.text ] ;then
        echo -n >$outd/core/.done_core
        echo "Complete processing transcription data in core"
    else
        echo "Bad processing of making transcriptions part" && exit;
    fi

    rm -r $outd/core/00README.txt
    wait

    if [ -e $outd/core/.done_core ] ;then
	echo -n >$outd/core/.done_make_trans
	echo "Done!"
    else
	echo "Bad processing of making transcriptions part" && exit;
    fi
)
fi

## Exclude speech data given by test set speakers.
if [ ! -e $outd/.done_mv_eval_dup ]; then
(
    echo "Make evaluation set for demo."
    mkdir -p $outd/eval/eval1
    
    mv $outd/core/A01M0097 $outd/eval/eval1

    if [ -e $outd/eval/eval1/A01M0097 ] ;then
        echo -n >$outd/.done_mv_eval_dup
        echo "Done!"
    else
        echo "Bad processing of making evaluation set part"
        exit 1;
    fi
    )
fi

## make lexicon.txt
if [ ! -e $outd/.done_make_lexicon ]; then
    echo "Make lexicon file."
    (
	lexicon=$outd/lexicon
	rm -f $outd/lexicon/lexicon.txt
	mkdir -p $lexicon
	cat $outd/*/*/*.4lex | grep -v "+ー" | grep -v "++" | grep -v "×" > $lexicon/lexicon.txt
	sort -u $lexicon/lexicon.txt > $lexicon/lexicon_htk.txt
	local/csj_make_trans/vocab2dic.pl -p local/csj_make_trans/kana2phone -e $lexicon/ERROR_v2d -o $lexicon/lexicon.txt $lexicon/lexicon_htk.txt
	cut -d'+' -f1,3- $lexicon/lexicon.txt >$lexicon/lexicon_htk.txt
	cut -f1,3- $lexicon/lexicon_htk.txt | sed 's:[\t]: :g' >$lexicon/lexicon.txt

    if [ -s $lexicon/lexicon.txt ] ;then
	echo -n >$outd/.done_make_lexicon
	echo "Done!"
    else
        echo "Bad processing of making lexicon file" && exit;
    fi
    )
fi

echo "Finish processing original CSJ data" && echo -n >$outd/.done_make_all
