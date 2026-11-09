import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/formatting/date_timestamp.dart';
import '../../../core/formatting/money_formatter.dart';
import '../../accounts/accounts_providers.dart';
import '../data/transactions_repository.dart';
import '../transactions_providers.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});
  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final _search = TextEditingController();
  String? _accountId;
  String? _category;
  String? _type;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  static const _months = ['January','February','March','April','May','June','July','August','September','October','November','December'];

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  int _day(DateTime d) => DateTime.utc(d.year,d.month,d.day).millisecondsSinceEpoch;

  Future<void> _trash(TransactionHistoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Move to Trash?'),
        content: const Text('You can restore this transaction later from Trash.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c,false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c,true), child: const Text('Move to Trash')),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(transactionsRepositoryProvider).softDeleteTransaction(item.transaction.id);
      ref.invalidate(accountBalancePaiseProvider(item.transaction.accountId));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not move transaction to Trash. Try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(transactionHistoryProvider(const TransactionHistoryFilter()));
    final accounts = ref.watch(allAccountsProvider);
    final colors = Theme.of(context).colorScheme;
    final start = DateTime(_month.year,_month.month);
    final end = DateTime(_month.year,_month.month+1).subtract(const Duration(days:1));
    final monthLabel = '${_months[_month.month-1]} ${_month.year}';

    return all.when(
      loading: () => const Center(child:CircularProgressIndicator()),
      error: (e,s) => Center(child:TextButton(
        onPressed: () => ref.invalidate(transactionHistoryProvider(const TransactionHistoryFilter())),
        child: const Text('Could not load history. Retry'),
      )),
      data: (items) {
        final from = _day(start), through = _day(end);
        final monthItems = items.where((i) => i.transaction.transactionDate >= from && i.transaction.transactionDate <= through);
        var income=0, expense=0;
        for(final i in monthItems) { if(i.transaction.type=='income') { income+=i.transaction.amountPaise; } else { expense+=i.transaction.amountPaise; } }
        final categories = items.map((i)=>i.categoryName).toSet().toList()..sort();
        final q = _search.text.trim().toLowerCase();
        final filtered = items.where((i) {
          final t=i.transaction;
          if(t.transactionDate<from || t.transactionDate>through) {
            return false;
          }
          if(_accountId!=null && t.accountId!=_accountId) {
            return false;
          }
          if(_category!=null && i.categoryName!=_category) {
            return false;
          }
          if(_type!=null && t.type!=_type) {
            return false;
          }
          if(q.isNotEmpty) {
            final searchable='${t.note??''} ${i.accountName} ${i.categoryName} ${MoneyFormatter.formatPaise(t.amountPaise)} ${t.amountPaise}'.toLowerCase();
            if(!searchable.contains(q)) {
              return false;
            }
          }
          return true;
        }).toList();
        final groups=<String,List<TransactionHistoryItem>>{};
        for(final i in filtered) { groups.putIfAbsent(DateOnly.format(i.transaction.transactionDate),()=>[]).add(i); }

        return Column(children:[
          Padding(
            padding: const EdgeInsets.fromLTRB(16,8,16,10),
            child: Column(children:[
              Row(children:[
                Expanded(child:Text('Monthly overview',style:AppTypography.sectionTitle.copyWith(color:colors.onSurface))),
                IconButton(tooltip:'Previous month',onPressed:()=>setState(()=>_month=DateTime(_month.year,_month.month-1)),icon:const Icon(Icons.chevron_left_rounded)),
                Text(monthLabel,style:AppTypography.supporting.copyWith(color:colors.onSurface,fontWeight:FontWeight.w600)),
                IconButton(tooltip:'Next month',onPressed:_month.year==DateTime.now().year&&_month.month==DateTime.now().month?null:()=>setState(()=>_month=DateTime(_month.year,_month.month+1)),icon:const Icon(Icons.chevron_right_rounded)),
              ]),
              Row(children:[
                Expanded(child:_SummaryTile(label:'Income',amount:income,color:AppColors.positive)),
                const SizedBox(width:8),
                Expanded(child:_SummaryTile(label:'Expenses',amount:expense,color:AppColors.negative)),
              ]),
              const SizedBox(height:10),
              TextField(
                controller:_search,onChanged:(_)=>setState((){}),
                decoration:InputDecoration(
                  hintText:'Search note, Account or amount',
                  prefixIcon:const Icon(Icons.search_rounded,size:19),
                  suffixIcon:q.isEmpty?null:IconButton(tooltip:'Clear search',onPressed:(){_search.clear();setState((){});},icon:const Icon(Icons.close_rounded,size:18)),
                ),
              ),
              const SizedBox(height:8),
              Row(children:[
                Expanded(child:SegmentedButton<String?>(
                  segments:const[
                    ButtonSegment(value:null,label:Text('All')),
                    ButtonSegment(value:'expense',label:Text('Expense')),
                    ButtonSegment(value:'income',label:Text('Income')),
                  ],
                  selected:{_type},showSelectedIcon:false,
                  onSelectionChanged:(v)=>setState(()=>_type=v.first),
                )),
                const SizedBox(width:8),
                IconButton.filledTonal(tooltip:'Open Trash',onPressed:()=>context.push('/transactions/trash'),icon:const Icon(Icons.delete_outline_rounded)),
              ]),
              const SizedBox(height:8),
              Row(children:[
                Expanded(child:accounts.when(
                  loading:()=>const LinearProgressIndicator(),
                  error:(e,s)=>const Text('Accounts unavailable.'),
                  data:(rows)=>DropdownButtonFormField<String?>(
                    initialValue:_accountId,isExpanded:true,
                    decoration:const InputDecoration(labelText:'Account',prefixIcon:Icon(Icons.account_balance_wallet_outlined,size:18)),
                    items:[const DropdownMenuItem(value:null,child:Text('All Accounts')),for(final a in rows) DropdownMenuItem(value:a.id,child:Text(a.name,overflow:TextOverflow.ellipsis))],
                    onChanged:(v)=>setState(()=>_accountId=v),
                  ),
                )),
                const SizedBox(width:8),
                Expanded(child:DropdownButtonFormField<String?>(
                  initialValue:_category,isExpanded:true,
                  decoration:const InputDecoration(labelText:'Category',prefixIcon:Icon(Icons.category_outlined,size:18)),
                  items:[const DropdownMenuItem(value:null,child:Text('All Categories')),for(final c in categories) DropdownMenuItem(value:c,child:Text(c,overflow:TextOverflow.ellipsis))],
                  onChanged:(v)=>setState(()=>_category=v),
                )),
              ]),
              if(_accountId!=null||_category!=null||_type!=null||q.isNotEmpty)
                Align(alignment:Alignment.centerRight,child:TextButton(
                  onPressed:()=>setState((){_accountId=null;_category=null;_type=null;_search.clear();}),
                  child:const Text('Clear filters'),
                )),
            ]),
          ),
          const Divider(height:1),
          Expanded(child:filtered.isEmpty
            ? Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[
                Icon(Icons.receipt_long_outlined,size:34,color:colors.onSurfaceVariant),
                const SizedBox(height:10),
                Text(items.isEmpty?'No transactions yet':'No matching transactions',style:AppTypography.sectionTitle.copyWith(color:colors.onSurface)),
                const SizedBox(height:4),
                Text(items.isEmpty?'Your transactions will appear here.':'Try changing your search or filters.',textAlign:TextAlign.center,style:AppTypography.supporting.copyWith(color:colors.onSurfaceVariant)),
              ])))
            :ListView(padding:const EdgeInsets.fromLTRB(16,10,16,100),children:[
                for(final group in groups.entries)...[
                  Padding(padding:const EdgeInsets.fromLTRB(2,8,2,6),child:Text(group.key,style:AppTypography.sectionTitle.copyWith(color:colors.onSurface))),
                  for(final item in group.value) _HistoryTile(
                    item:item,
                    onTap:()=>context.push('/transaction/${item.transaction.id}'),
                    onEdit:()=>context.push('/transaction/${item.transaction.id}/edit'),
                    onTrash:()=>_trash(item),
                  ),
                ],
              ]),
          ),
        ]);
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label,required this.amount,required this.color});
  final String label; final int amount; final Color color;
  @override
  Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
    decoration:BoxDecoration(color:Theme.of(context).colorScheme.surface,borderRadius:BorderRadius.circular(12),border:Border.all(color:Theme.of(context).colorScheme.outlineVariant.withValues(alpha:.65))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(label,style:AppTypography.supporting.copyWith(color:Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height:4),
      Text(MoneyFormatter.formatPaise(amount),maxLines:1,overflow:TextOverflow.ellipsis,style:AppTypography.transactionAmount.copyWith(color:color)),
    ]),
  );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item,required this.onTap,required this.onEdit,required this.onTrash});
  final TransactionHistoryItem item; final VoidCallback onTap,onEdit,onTrash;
  @override
  Widget build(BuildContext context){
    final t=item.transaction; final income=t.type=='income'; final colors=Theme.of(context).colorScheme;
    return Container(
      margin:const EdgeInsets.only(bottom:7),
      decoration:BoxDecoration(color:colors.surface,borderRadius:BorderRadius.circular(13),border:Border.all(color:colors.outlineVariant.withValues(alpha:.65))),
      child:ListTile(
        onTap:onTap,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:3),
        leading:Container(width:36,height:36,decoration:BoxDecoration(color:(income?AppColors.positive:AppColors.negative).withValues(alpha:.09),borderRadius:BorderRadius.circular(11)),child:Icon(income?Icons.south_west_rounded:Icons.north_east_rounded,color:income?AppColors.positive:AppColors.negative,size:18)),
        title:Text(t.note?.isNotEmpty==true?t.note!:item.categoryName,maxLines:1,overflow:TextOverflow.ellipsis,style:AppTypography.supporting.copyWith(color:colors.onSurface,fontWeight:FontWeight.w600)),
        subtitle:Text('${item.categoryName} · ${item.accountName}',maxLines:1,overflow:TextOverflow.ellipsis,style:AppTypography.supporting.copyWith(color:colors.onSurfaceVariant)),
        trailing:Row(mainAxisSize:MainAxisSize.min,children:[
          Text('${income?'+':'-'}${MoneyFormatter.formatPaise(t.amountPaise)}',style:AppTypography.transactionAmount.copyWith(color:income?AppColors.positive:AppColors.negative)),
          PopupMenuButton<String>(tooltip:'Transaction actions',onSelected:(v){if(v=='edit') {
              onEdit();
            }
            if(v=='trash') {
              onTrash();
            }},itemBuilder:(_)=>const[
            PopupMenuItem(value:'edit',child:Text('Edit')),
            PopupMenuItem(value:'trash',child:Text('Move to Trash')),
          ]),
        ]),
      ),
    );
  }
}
