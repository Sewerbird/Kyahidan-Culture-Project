# Kyahidan Phonology

## Kyahidan Vowels

* ā  á  a -> /aᶦ ä ɑᵘ/
* ē  é  e -> /eᶦ ɛ ə/
* ī  i  u -> /iᶦ ɨ u/

## Kyahidan Consonants

* b d -> /v ð/ or /b d/ if beginning a word
* k h -> /k h/
* r l m n -> /ʁ l m n/
* c j s z -> /ʒ dʒ s z/
* y -> /j/ unless before ī or i: then /w/
* st -> /st/

## Kyahidan Syllables

With 

*  v0 = ["ā","á","a","ē","é","e","ī","i","u"]
*  v1 = ["yá","ya","yi","yu","yé","ye","i","e"]
*  v2 = ["á","e","u"]
*  c0 = ["b","d","r","l","m","n"]
*  c1 = ["c","j","s","z"]
*  c2 = ["b","d","l","st"]
*  c3 = ["k","h"]

Valid syllables: 

*  s0 = [];//Basic syllables = c0v0
*  s1 = [];//K-H syllables = c3v1
*  s2 = [];//Coda syllables = c1v0c2
*  s3 = [];//Fricative Syllables = c1v2
*  s4 = [];//Vowel-Onset Syllables = v2

With

pre = s0|s1|s3
coda = s0|s1|s2|s3
voc = s4

Valid words are: 

(voc + pre | (pre)* + coda)
s4[s0|s1|s3] | (s0|s1|s3)*[s0|s1|s2|s3]
v2[c0v0|c3v1|c1v2] | (c0v0|c3v1|c1v2)*[c0v0|c3v1|c1v0c2|c1v2]
