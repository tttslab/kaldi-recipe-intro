echo 'あらゆる現実をすべて自分のほうへねじ曲げたのだ。' > sample.txt
echo '一週間ばかりニューヨークを取材した。' >> sample.txt
echo 'テレビゲームやパソコンでゲームをして遊ぶ。' >> sample.txt
mecab sample.txt -o morph.txt
