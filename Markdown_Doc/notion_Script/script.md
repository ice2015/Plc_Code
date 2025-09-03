### ifs Origin 
    ifs(prop("Days Until") == 0, "今天".style("green", "b"),
    prop("Days Until") == 1, "明天".style("green", "b"),
    prop("Days Until") < 0, "活动已过".style("red", "b"),
    join([format(prop("Days Until")), "天后"], " ").style("b"))
### ifs Origin 
    ifs(and(prop("未处理")==0,prop("结算类型")=="奖励" ) ,"全部发放".style("green","b"),and(prop("未处理")==0,prop("结算类型")=="扣款"),"扣款完成".style("orange","b"),and(prop("未处理")<0,prop("结算类型")=="扣款"),"部分扣款".style("Brown","b"),and(prop("未处理")<>0,prop("结算类型")=="奖励"),"部分奖励".style("Blue","b"),"部分处理".style("red","b") )

### modify###############
    ifs(and(prop("未处理")==0,prop("结算类型")=="奖励" ),"全部发放".style("Grey","b"),and(prop("未处理")==prop("结算金额"),prop("结算类型")=="奖励"),"未发放".style("green","b"),and(prop("未处理")==0,prop("结算类型")=="扣款"),"扣款完成".style("orange","b"),and(prop("未处理")<0,prop("未处理") !=  prop("结算金额") *-1 ,prop("结算类型")== "扣款"),"部分扣款".style("brown","b") , and(prop("未处理") ==prop("结算金额")*-1,prop("结算类型")=="扣款"),"扣款未执行".style("Purple","b"),"部分奖励".style("red","b") )
### 使用 Rollup 列进行 if 条件判断时遇到的问题，都源于对 Rollup 返回值类型的误解
    if(join(prop("关联类型"), ",") == "奖励,扣款", "混合", if(join(prop("关联类型"), ",") == "奖励", "只有奖励", if(join(prop("关联类型"), ",") == "扣款", "只有扣款", "未结算")))
+ **场景：**您有一个 Rollup 属性“结算金额”，它汇总了多个结算明细的金额。Show unique values 可能会返回 [150, 200]。您 想判断所有这些唯一的金额是否都大于100且小于200。
    prop("结算金额").map(current => current > 100 and current < 200).every(current => current == true)
    公式分解：

    prop("结算金额")：获取 Rollup 列返回的列表，例如 [150, 200]。

    .map(current => current > 100 and current < 200)：对列表中的每个值进行判断，并返回一个布尔值列表。

    150 > 100 and 150 < 200 返回 true。

    200 > 100 and 200 < 200 返回 false。

    所以，.map() 的结果是 [true, false]。

    .every(current => current == true)：检查 [true, false] 这个列表中的所有值是否都是 true。因为列表中有一个 false，所以这个最终结果是 false。

    如果您想判断只要有一个值满足条件即可，可以使用 some() 函数，它会检查列表中是否有任何一个值为 true。
    公式示例：
    prop("结算金额").map(current => current > 100 and current < 200).some(current => current == true)
    **提示：**这种公式非常强大，但理解起来也比较复杂。在大多数情况下，如果您只需要对总和、平均值等进行判断，直接在 Rollup 中选择 Sum 或 Average，然后再进行简单的 if 比较会更简单。只有当您确实需要对每一个唯一的、汇总的值进行判断时，才需要使用 map() 和 every() / some()。