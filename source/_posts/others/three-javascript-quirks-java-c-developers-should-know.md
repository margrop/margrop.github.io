---
title: Java / C开发人员应该知道的三个JavaScript怪癖
cover: /images/banner/1005_20240927_021343.webp
coverWidth: 1280
coverHeight: 720
tags:
  - javascript
  - js
  - scoping
  - hoisting
  - function
  - with
  - closures
published: true
hideInList: false
isTop: false
categories:
  - others
date: 2021-02-28 22:28:36
feature:
---
JavaScript可能是一种欺骗性的语言，并且可能会造成极大的痛苦，因为它不是100％一致的。众所周知，它确实存在一些不好的，令人迷惑的或冗余的功能：臭名昭著的[with语句]()，[隐式全局变量](http://yuiblog.com/blog/2006/06/01/global-domination/)和[不稳定的比较](http://dorey.github.io/JavaScript-Equality-Table/)可能是最著名的。


JavaScript是历史上最成功的火焰生成器之一！除了它所存在的缺陷（在新的ECMAScript规范中部分解决了这些缺陷）之外，大多数程序员都讨厌JavaScript的原因有两个：

 * 他们错误地认为DOM等同于JavaScript语言，该语言具有相当糟糕的API。

 * 它们来自C和Java等语言的JavaScript。他们被JavaScript的语法迷住了，以为它的工作方式与那些命令式语言的工作方式相同。这种误解将导致混乱，沮丧和错误。
   

因此，通常JavaScript的声誉比其应有的差。

在我的职业生涯中，我注意到了几种模式：大多数具有Java或C / C ++背景的开发人员所使用的语言功能在JavaScript中都假定相同，而又完全不同。

本文收集了最麻烦的文章，将Java方式与JavaScript方式进行比较以显示差异，并重点介绍JavaScript的最佳实践。

<!-- more -->

# 作用域
大多数开发人员因为被迫而开始使用JavaScript，因此几乎所有的开发人员都在花一点时间学习该语言之前就开始编写代码。每个这样的开发人员都至少一次受到过JavaScript范围的欺骗。

因为JavaScript的语法非常类似于（故意）C系列语言，并且用花括号分隔了`function`，`if`和`for`主体，所以人们可以合理地期望词汇块级作用域。不幸的是，这种情况并非如此。

首先，在JavaScript中，变量作用域是由函数而不是方括号来确定的。换句话说，`if`和`for`主体不会创建新的作用域，并且实际上会提升在其主体中声明的变量，即，在声明该变量的最内层函数的开始处创建该变量，否则在全局范围内创建该变量。

其次，该`with`语句的存在迫使JavaScript作用域是动态的，直到运行时才能确定。听到`with`不赞成使用该语句，您可能不会感到惊讶：剥离的JavaScript`with`实际上是一种词法范围的语言，即可以通过查看代码来完全确定范围。

正式地，在JavaScript中，有四种来定义一个变量作用域：

* 语言预定义：默认情况下，所有作用域都包含名称`this`和`arguments`。
* 形式参数：为一个函数声明的任何（形式）参数的范围都限于该函数的主体。
* 函数声明
* 变量声明

进一步的复杂性是由于隐式全局作用域引起的，该隐式全局作用域分配给（隐式）声明的没有var关键字的变量。这种疯狂与在`this`没有显式绑定的情况下调用函数时要引用的全局范围的隐式分配成对（在下一节中将对此进行详细介绍）。

在深入研究细节之前，让我们清楚地说明可以用来避免混淆的良好模式：

使用严格模式`（'use strict';）`，并将所有变量和函数声明移至每个函数的顶部；避免在`for`和`if`块内声明变量，以及在这些块内声明函数（出于不同的原因，这超出了本文的范围）。

# 变量提升(Hoisting)
变量提升是一种简化形式，用于解释声明的实际行为。提升变量在包含它们的函数的开头声明，并初始化为`undefined`。然后，在原始声明所在的实际行中进行赋值。

看下面的例子：
```js
function myFunction() {
  console.log(i);
  var i = 0;
  console.log(i);
  if (true) {
    var i = 5;
    console.log(i);
  }
  console.log(i);
}
```
您希望将什么值打印到控制台？您会对以下输出感到惊讶吗？
```
undefined
0
5
5
```
在该`if`块内部，该`var`语句未声明该变量的本地副本i，而是覆盖了之前声明的副本。请注意，第一条`console.log`语句显示变量的实际值`i`，该变量的初始值设置为`undefined`。您可以通过将该`"use strict";`指令用作函数的第一行来对其进行测试。在严格模式下，必须先声明变量，然后才能使用它，但是您可以检查JavaScript引擎不会抱怨该声明。在一个侧面说明，要知道，你会得到不抱怨的重新声明一`var`：如果你想赶上这样的错误，你应该更好地处理与棉绒这样的代码JSHint或JSLint的。

现在，让我们再看一个示例，以突出显示变量声明的另一种易于出错的用法：

```js
var notNull = 1;
function test() {
  if (!notNull) {
    console.log("Null-ish, so far", notNull);
    for(var notNull = 10; notNull <= 0; notNull++){
      //..
    }
    console.log("Now it's not null", notNull);
  }
  console.log(notNull);
}
```
尽管您可能会有不同的期望，但`if`主体仍会执行，因为`notNull`在`test()`函数内部声明了名为的变量的本地副本，并且该主体已被提升。类型强制在这里也起作用。

# 函数声明与函数表达式
提升不仅适用于变量，函数表达式（对于所有意图和用途都是变量），并且函数声明也同样适用。与本主题相比，需要更加谨慎地对待该主题，但是简而言之，函数声明的行为主要类似于函数表达式，只是将它们的声明移到其作用域的开头。

考虑以下示例，该示例显示了函数声明的行为：

```js
function foo() {
    // A function declaration
    function bar() {
        return 3;
    }
    return bar();

    // This function declaration will be hoisted and overwrite the previous one
    function bar() {
        return 8;
    }
}

```

现在，将其与显示函数表达式行为的示例进行比较：
```js
function foo() {
    // A function expression
    var bar = function() {
        return 3;
    };
    return bar();

    // The variable bar already exists, and this code will never be reached
    var bar = function() {
        return 8;
    };
}
```
有关这些概念的进一步了解，请参见参考资料部分。

# With
以下示例显示了只能在运行时确定作用域的情况：
```js
function foo(y) {
  var x = 123;
  with(y) {
    return x;
  }
}
```
如果y有一个名为的字段x，则函数foo()将返回y.x，否则它将返回123。这种编码做法可能会导致运行时错误，因此强烈建议您避免使用该with语句。

# 展望未来：ECMAScript 6
ECMAScript 6规范将添加添加块级作用域的第五种方法：`let`语句。考虑下面的代码：
```js
function myFunction() {
  console.log(i);
  var i = 0;
  console.log(i);
  if (false) {
    let i = 5;
    console.log(i);
  }
  console.log(i);
}
```
ECMAScript中6，声明`i`与`let`的体内`if`将创建一个新的变量本地的if块。作为一种非标准的选择，可以`let`如下声明块：
```js
var i = 6;
let (i = 0, j = 2) {
  /* Other code here */
}
// prints 6
console.log(i);
```
在上面的代码中，变量`i`和`j`将仅存在于块内部。在撰写本文时，对支持`let`有限，即使对于Chrome也是如此。

# 作用域(Scopes)总结
下表总结了不同语言的作用域：

特征|Java|Python|JavaScript|Warnings
---|---|---|---|---
作用域|词法（块）|词法（函数，类或模块）|是的|它的工作方式与Java或C截然不同
块作用域|是的|不|`let`关键字（ES6）|再次警告：这不是Java！
吊装|决不！|不|是的|对于变量和函数表达式，仅悬挂声明。对于函数声明，该定义也将被提升

# 函数(Funtions)
JavaScript的另一个非常容易被误解的功能是函数，尤其是因为在命令式编程语言中Java，没有这样的概念。

实际上，JavaScript是一种功能编程语言。嗯，不是像Haskell那样的纯粹的函数式编程语言-毕竟，它仍然具有命令式的风格，并且像Scala一样，鼓励而不是简单地允许可变性。尽管如此，JavaScript仍可以用作纯函数式编程语言，而函数调用没有任何副作用。

# 一等公民(First-Class Citizens)
JavaScript中的函数可以像其他任何类型一样对待，例如String和Number：它们可以存储在变量中，作为参数传递给函数，由函数返回，并存储在数组中。函数还可以具有属性，并且可以动态更改，这是因为…

# 对象(Objects)
对于大多数JavaScript新手来说，一个非常令人惊讶的事实是函数实际上是对象。在JavaScript中，每个函数实际上都是一个`Function`对象。该`Function`构造函数创建一个新的`Function`对象：
```js
var func = new Function(['a', 'b', 'c'], '');
```
（几乎）等于：
```js
function func(a, b, c) { }
```
我说它们几乎是等效的，因为使用`Function`构造函数的效率较低，会生成匿名函数，并且不会为其创建上下文创建闭包。`Function`对象总是在全局范围内创建。

`Function`函数的类型建立在`Object`上。通过检查您声明的任何函数，可以很容易看出这一点：

```js
function test() {}
//  prints  "object"
console.log(typeof test.prototype);
//  prints  function Function() { [native code] }
console.log(test.constructor);
```
这意味着函数可能并且确实具有属性。其中一些已分配给创建时的功能，例如`name`或`length`。这些属性分别返回函数定义中的参数名称和数量。

考虑以下示例：
```js
function func(a, b, c) { }
//  prints "func"
console.log(func.name);
//  prints 3
console.log(func.length);
```
但是您甚至可以自己为任何函数设置新属性：
```js
function test() {
  console.log(test.custom);
}
test.custom = 123;
//  prints 123
test();
```
# 函数总结
下表描述了Java，Python和JavaScript中的函数：

特征|Java|Python|JavaScript|Warnings
---|---|---|---|---
内置功能|Java 8 Lambdas|是的|是的|
回调/命令模式|对象（或Java 8的lambda）|是的|是的|函数（回调）具有可以由“客户端”修改的属性
动态创建|不|不|eval-功能对象|eval具有安全性考虑，Function对象可能无法正常工作
属性|不|不|可以有属性|不能限制对函数属性的访问

# 闭包
如果不得不选择我最喜欢的JavaScript功能，那么毫无疑问我会选择闭包。JavaScript是第一种引入闭包的主流编程语言。如您所知，Java和Python的闭包功能弱化了很长时间，您只能从封装作用域中读取（某些）值。

例如，在Java中，匿名内部类提供了类似闭包的功能，但有一些限制。例如，只能在其范围内使用最终局部变量-更好的说，可以读取它们的值。

JavaScript允许完全访问外部范围的变量和函数。可以读取，编写它们，并且如果需要的话，甚至可以将它们隐藏在本地定义中：您可以在“作用域”部分中查看所有这些情况的示例。

更有趣的是，在闭包中创建的函数会记住创建该函数的环境。通过结合使用闭包和函数嵌套，可以使外部函数返回内部函数而不执行它们。此外，您可以使外部函数的局部变量在声明内部函数的执行结束后很长一段时间内在内部函数的关闭中幸存。这是一个非常强大的功能，但也有缺点，因为它是JavaScript应用程序中内存泄漏的常见原因。

一些示例将阐明这些概念：
```js
function makeCounter () {
  var i = 0;

  return function displayCounter () {
    console.log(++i);
  };
}
var counter = makeCounter();
//  prints 1
counter();
//  prints 2
counter();
```
`makeCounter()`上面的函数创建并返回另一个跟踪其创建环境的函数。尽管在分配`makeCounter()`变量时执行结束`counter`，但是局部变量`i`保留在`displayCounter`的闭包中，因此可以在其主体内部进行访问。

如果我们`makeCounter`再次运行，它将创建一个新的闭包，并带有一个不同的条目i：
```js
var counterBis = makeCounter();
//  prints 1
counterBis();
//  prints 3
counter();
//  prints 2
counterBis();
```
为了使它更有趣，我们可以更新该`makeCounter()`函数，使其带有一个参数：
```js
function makeCounter(i) {
  return function displayCounter () {
    console.log(++i);
  };
}
var counter = makeCounter(10);
//  prints 11
counter();
//  prints 12
counter();
```
外部函数参数也保留在闭包中，因此我们这次无需声明局部变量。每次致电`makeCounter()`都会记住我们设置的初始值，然后继续使用。

对于许多基本的JavaScript模式而言，闭包是最重要的：命名空间，模块，私有var，备忘录是最著名的。

作为示例，让我们看看如何模拟对象的私有变量：
```js
function Person(name) {
  return {
    setName: function(newName) {
      if (typeof newName === 'string' && newName.length > 0) {
        name = newName;
      } else {
        throw new TypeError("Not a valid name");
      }
    },
    getName: function () {
      return name;
    }
  };
}

var p = Person("Marcello");

// prints "Marcello"
a.getName();

// Uncaught TypeError: Not a valid name
a.setName();

// Uncaught TypeError: Not a valid name
a.setName(2);
a.setName("2");

// prints "2"
a.getName();
```
通过这种模式，利用闭包，我们可以使用我们自己的setter和getter为属性名称创建包装器。ES5使得此过程变得容易得多，因为您可以使用具有属性的getter和setter的对象来创建对象，并以最精细的方式控制对属性本身的访问。

# 闭包总结
下表描述了Java，Python和JavaScript中的闭包：

特征|Java|Python|JavaScript|Warnings
---|---|---|---|---
关闭|匿名内部类中的弱类（只读）|嵌套def中的弱功能（只读）|是的|内存泄漏
记忆模式|必须使用共享对象|可能使用列表或字典|是的|更好地使用惰性评估
命名空间/模块模式|并不需要|并不需要|是的|  
私有属性模式|并不需要|不可能|是的|可能会造成混乱
# 结论
在本文中，我介绍了JavaScript的三个功能，这些功能经常被来自不同语言（尤其是Java和C）的开发人员所误解。特别是，我们讨论了范围，托管，函数和闭包等概念。如果您想深入研究这些主题，请阅读以下文章列表：
* JavaScript范围界定
* 函数声明与函数表达式
* `Let`声明和`let`块

文章来源
<https://www.sitepoint.com/three-javascript-quirks-java-c-developers-should-know/>