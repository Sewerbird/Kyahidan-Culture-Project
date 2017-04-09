var v0 = ["ā","á","a","ē","é","e","ī","i","u"]
var v1 = ["yá","ya","yi","yu","yé","ye","i","e"]
var v2 = ["á","e","u"]
var c0 = ["b","d","r","l","m","n"]
var c1 = ["c","j","s","z"]
var c2 = ["b","d","l","st"]
var c3 = ["k","h"]

var s0 = [];//Basic syllables = c0v0
var s1 = [];//K-H syllables = c3v1
var s2 = [];//Coda syllables = c1v0c2
var s3 = [];//Fricative Syllables = c1v2
var s4 = [];//Vowel-Onset Syllables = v2

for(var i = 0; i < c0.length; i ++)
{
	for(var j = 0; j < v0.length; j++)
	{
		s0.push(c0[i]+v0[j])
	}
}
for(var i = 0; i < c3.length; i ++)
{
	for(var j = 0; j < v1.length; j++)
	{
		s1.push(c3[i]+v1[j])
	}
}
for(var i = 0; i < c1.length; i ++)
{
	for(var j = 0; j < v0.length; j++)
	{
		for(var k = 0; k < c2.length; k++)
		{
			s2.push(c1[i]+v0[j]+c2[k])
		}
	}
}
for(var i = 0; i < c1.length; i ++)
{
	for(var j = 0; j < v2.length; j++)
	{
		s3.push(c1[i]+v2[j])
	}
}
for(var i = 0; i < v2.length; i ++)
{
	s4.push(v2[i])
}
console.log(s0,s1,s2,s3,s4,s0.length+s1.length+s2.length+s3.length+s4.length,countWords())

function countWords(){
	var pre = _.union(s0,s1,s3);
	var coda = _.union(s0,s1,s2,s3);
	return coda.length + (s4.length * pre.length) + (pre.length*pre.length*coda.length) + (pre.length * coda.length) + (coda.length*pre.length);
}
function generateWords(number){
	var words = [];
	var pre = _.union(s0,s1,s3);
	var coda = _.union(s0,s1,s2,s3);
	for(var i = 0; i < number; i++)
	{
		if(Math.random()<0.1)//one syllable
		{
			words.push(_.sample(coda))
		}
		else if(Math.random()<0.1)//no onset consonant
		{
			words.push(_.sample(s4)+_.sample(pre))
		}
		else if(Math.random()<0.3)//three syllable
		{
			words.push(_.sample(pre)+_.sample(pre)+_.sample(coda))
		}
		else if(Math.random()<0.1)//coda+onset
		{
			words.push(_.sample(coda)+_.sample(s4))
		}
		else
		{
			words.push(_.sample(pre)+_.sample(coda))
		}
	}
	return words;
}