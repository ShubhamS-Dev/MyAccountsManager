import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/formatting/date_timestamp.dart';
import '../../../core/formatting/money_formatter.dart';
import '../../accounts/accounts_providers.dart';
import '../../categories/categories_providers.dart';
import '../transactions_providers.dart';

class TransactionDetailsPage extends ConsumerWidget {
  const TransactionDetailsPage({super.key,required this.transactionId});
  final String transactionId;

  @override
  Widget build(BuildContext context,WidgetRef ref){
    final result=ref.watch(transactionByIdProvider(transactionId));
    final colors=Theme.of(context).colorScheme;
    return Scaffold(
      appBar:AppBar(title:const Text('Transaction details')),
      body:result.when(
        loading:()=>const Center(child:CircularProgressIndicator()),
        error:(e,s)=>Center(child:TextButton(onPressed:()=>ref.invalidate(transactionByIdProvider(transactionId)),child:const Text('Could not load transaction. Retry'))),
        data:(row){
          if(row==null||row.deletedAt!=null) {
            return const Center(
              child:Text('This transaction is unavailable or has been moved to Trash.'),
            );
          }
          final accounts=ref.watch(allAccountsProvider);
          final categories=ref.watch(activeCategoriesByTypeProvider(row.type));
          final income=row.type=='income';
          return ListView(padding:const EdgeInsets.all(16),children:[
            Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:colors.surface,borderRadius:BorderRadius.circular(16),border:Border.all(color:colors.outlineVariant)),child:Column(children:[
              Icon(income?Icons.south_west_rounded:Icons.north_east_rounded,size:28,color:income?AppColors.positive:AppColors.negative),
              const SizedBox(height:10),
              Text(income?'Income':'Expense',style:AppTypography.supporting.copyWith(color:colors.onSurfaceVariant)),
              const SizedBox(height:5),
              Text('${income?'+':'-'}${MoneyFormatter.formatPaise(row.amountPaise)}',style:AppTypography.transactionAmount.copyWith(color:income?AppColors.positive:AppColors.negative)),
              if(row.note?.isNotEmpty==true)...[const SizedBox(height:8),Text(row.note!,style:AppTypography.sectionTitle.copyWith(color:colors.onSurface))],
            ])),
            const SizedBox(height:16),
            _DetailRow(label:'Account',value:accounts.when(data:(v){final matches=v.where((a)=>a.id==row.accountId);return matches.isEmpty?'Unavailable':matches.first.name;},loading:()=>'Loading…',error:(e,s)=>'Unavailable')),
            _DetailRow(label:'Category',value:categories.when(data:(v){final matches=v.where((c)=>c.id==row.categoryId);return matches.isEmpty?'Unavailable':matches.first.name;},loading:()=>'Loading…',error:(e,s)=>'Unavailable')),
            _DetailRow(label:'Transaction date',value:DateOnly.format(row.transactionDate)),
            _DetailRow(label:'Created',value:DateOnly.format(row.createdAt)),
            _DetailRow(label:'Last updated',value:DateOnly.format(row.updatedAt)),
            const SizedBox(height:18),
            SizedBox(height:40,child:FilledButton.icon(onPressed:()=>context.push('/transaction/$transactionId/edit'),icon:const Icon(Icons.edit_outlined,size:16),label:const Text('Edit transaction'))),
          ]);
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label,required this.value});
  final String label,value;
  @override
  Widget build(BuildContext context)=>Padding(
    padding:const EdgeInsets.symmetric(vertical:12),
    child:Row(children:[
      Expanded(child:Text(label,style:AppTypography.supporting.copyWith(color:Theme.of(context).colorScheme.onSurfaceVariant))),
      Flexible(child:Text(value,textAlign:TextAlign.end,style:AppTypography.supporting.copyWith(color:Theme.of(context).colorScheme.onSurface,fontWeight:FontWeight.w600))),
    ]),
  );
}
