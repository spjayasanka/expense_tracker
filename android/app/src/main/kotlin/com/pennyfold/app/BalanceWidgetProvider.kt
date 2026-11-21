package com.pennyfold.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget showing the total balance with quick-add buttons.
 * Data comes from local shared preferences written by the app; no network.
 */
class BalanceWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.balance_widget).apply {
                setTextViewText(
                    R.id.widget_label,
                    widgetData.getString("balance_label", null)
                        ?: context.getString(R.string.widget_balance_label),
                )
                setTextViewText(R.id.widget_balance, widgetData.getString("balance", null) ?: "—")

                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
                setOnClickPendingIntent(
                    R.id.widget_add_expense,
                    HomeWidgetLaunchIntent.getActivity(
                        context, MainActivity::class.java, Uri.parse("pennyfold://add?type=expense"),
                    ),
                )
                setOnClickPendingIntent(
                    R.id.widget_add_income,
                    HomeWidgetLaunchIntent.getActivity(
                        context, MainActivity::class.java, Uri.parse("pennyfold://add?type=income"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
